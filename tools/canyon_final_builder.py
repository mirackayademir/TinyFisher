#!/usr/bin/env python3
"""Build and verify TinyFisher's approved final canyon chunk payload.

The approved source is an exact Q95 RGBA WebP. This tool deliberately refuses
any source that does not match the locked size/SHA/geometry so a visually
similar replacement cannot silently enter the game.

Usage:
    python tools/canyon_final_builder.py build /path/to/canyon_q95.webp
    python tools/canyon_final_builder.py verify
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import shutil
import struct
import sys
import tempfile
from pathlib import Path

PART_PREFIX = "canyon_final_q95_part"
PART_COUNT = 41
CHUNK_BASE64_LENGTH = 16_000
EXPECTED_BASE64_LENGTH = 642_596
EXPECTED_RAW_BYTES = 481_946
EXPECTED_WIDTH = 1226
EXPECTED_HEIGHT = 1283
EXPECTED_SHA256 = "b00865a0d42d6488159f9ecf4cbde30df86873d96036f6630d548ec68f429679"

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = REPO_ROOT / "assets" / "environment" / "terrain" / "runtime_data_final"
MANIFEST_NAME = "canyon_final_q95_manifest.json"


class CanyonBuildError(RuntimeError):
    pass


def fail(message: str) -> "NoReturn":
    raise CanyonBuildError(message)


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def expected_part_length(index: int) -> int:
    if index < 0 or index >= PART_COUNT:
        fail(f"Invalid part index: {index}")
    if index < PART_COUNT - 1:
        return CHUNK_BASE64_LENGTH
    return EXPECTED_BASE64_LENGTH - CHUNK_BASE64_LENGTH * (PART_COUNT - 1)


def inspect_webp(data: bytes) -> tuple[int, int, bool]:
    """Return (width, height, alpha_flag) from a VP8X WebP container."""
    if len(data) < 20:
        fail("Source is too small to be a valid WebP.")
    if data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        fail("Source is not a RIFF/WEBP file.")

    riff_size = struct.unpack_from("<I", data, 4)[0] + 8
    if riff_size != len(data):
        fail(f"RIFF size mismatch: header={riff_size} actual={len(data)}")

    pos = 12
    while pos + 8 <= len(data):
        fourcc = data[pos : pos + 4]
        chunk_size = struct.unpack_from("<I", data, pos + 4)[0]
        payload_start = pos + 8
        payload_end = payload_start + chunk_size
        if payload_end > len(data):
            fail(
                f"Truncated WebP chunk {fourcc!r}: "
                f"needs {chunk_size} bytes at offset {payload_start}"
            )

        if fourcc == b"VP8X":
            if chunk_size < 10:
                fail(f"Invalid VP8X chunk size: {chunk_size}")
            payload = data[payload_start:payload_end]
            flags = payload[0]
            width = 1 + int.from_bytes(payload[4:7], "little")
            height = 1 + int.from_bytes(payload[7:10], "little")
            has_alpha = bool(flags & 0x10)
            return width, height, has_alpha

        pos = payload_end + (chunk_size & 1)

    fail("VP8X chunk not found; approved RGBA source is expected to use VP8X.")


def validate_source(data: bytes) -> None:
    if len(data) != EXPECTED_RAW_BYTES:
        fail(f"Raw byte mismatch: got={len(data)} expected={EXPECTED_RAW_BYTES}")

    actual_sha = sha256_hex(data)
    if actual_sha != EXPECTED_SHA256:
        fail(f"SHA256 mismatch: got={actual_sha} expected={EXPECTED_SHA256}")

    encoded = base64.b64encode(data)
    if len(encoded) != EXPECTED_BASE64_LENGTH:
        fail(
            f"Base64 length mismatch: got={len(encoded)} "
            f"expected={EXPECTED_BASE64_LENGTH}"
        )

    width, height, has_alpha = inspect_webp(data)
    if (width, height) != (EXPECTED_WIDTH, EXPECTED_HEIGHT):
        fail(
            f"WebP geometry mismatch: got={width}x{height} "
            f"expected={EXPECTED_WIDTH}x{EXPECTED_HEIGHT}"
        )
    if not has_alpha:
        fail("VP8X alpha flag is not set; approved transparent RGBA source required.")


def part_name(index: int) -> str:
    return f"{PART_PREFIX}{index:02d}.txt"


def build_chunks(source: Path, output_dir: Path) -> None:
    if not source.is_file():
        fail(f"Source file not found: {source}")

    raw = source.read_bytes()
    validate_source(raw)
    encoded = base64.b64encode(raw).decode("ascii")

    parts = [
        encoded[i * CHUNK_BASE64_LENGTH : (i + 1) * CHUNK_BASE64_LENGTH]
        for i in range(PART_COUNT)
    ]
    if len(parts) != PART_COUNT:
        fail(f"Internal split error: got {len(parts)} parts")
    for index, chunk in enumerate(parts):
        expected = expected_part_length(index)
        if len(chunk) != expected:
            fail(
                f"Internal part length error part{index:02d}: "
                f"got={len(chunk)} expected={expected}"
            )

    output_dir.mkdir(parents=True, exist_ok=True)
    temp_dir = Path(tempfile.mkdtemp(prefix="canyon_final_build_", dir=str(output_dir.parent)))

    try:
        chunk_hashes: list[dict[str, object]] = []
        for index, chunk in enumerate(parts):
            path = temp_dir / part_name(index)
            path.write_text(chunk, encoding="ascii", newline="")
            chunk_hashes.append(
                {
                    "index": index,
                    "file": path.name,
                    "base64_length": len(chunk),
                    "sha256_text": sha256_hex(chunk.encode("ascii")),
                }
            )

        manifest = {
            "format": "TinyFisher final canyon chunk manifest v1",
            "part_count": PART_COUNT,
            "chunk_base64_length": CHUNK_BASE64_LENGTH,
            "base64_length": EXPECTED_BASE64_LENGTH,
            "raw_bytes": EXPECTED_RAW_BYTES,
            "width": EXPECTED_WIDTH,
            "height": EXPECTED_HEIGHT,
            "rgba_transparency_required": True,
            "sha256_raw": EXPECTED_SHA256,
            "parts": chunk_hashes,
        }
        (temp_dir / MANIFEST_NAME).write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )

        staged_encoded = "".join(
            (temp_dir / part_name(i)).read_text(encoding="ascii").strip()
            for i in range(PART_COUNT)
        )
        if staged_encoded != encoded:
            fail("Staged chunk readback differs from source Base64.")
        staged_raw = base64.b64decode(staged_encoded, validate=True)
        if staged_raw != raw:
            fail("Staged chunk decode differs from source bytes.")
        validate_source(staged_raw)

        for stale in output_dir.glob(f"{PART_PREFIX}*.txt"):
            stale.unlink()
        for stale in output_dir.glob("canyon_final_q95_tail*.txt"):
            stale.unlink()
        manifest_path = output_dir / MANIFEST_NAME
        if manifest_path.exists():
            manifest_path.unlink()

        for index in range(PART_COUNT):
            shutil.move(str(temp_dir / part_name(index)), str(output_dir / part_name(index)))
        shutil.move(str(temp_dir / MANIFEST_NAME), str(output_dir / MANIFEST_NAME))
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

    verify_chunks(output_dir)
    print(
        "FINAL CANYON BUILD VERIFIED: "
        f"{PART_COUNT} parts / {EXPECTED_RAW_BYTES} bytes / "
        f"SHA256={EXPECTED_SHA256} / {EXPECTED_WIDTH}x{EXPECTED_HEIGHT} RGBA"
    )


def verify_chunks(output_dir: Path) -> None:
    missing = [part_name(i) for i in range(PART_COUNT) if not (output_dir / part_name(i)).is_file()]
    if missing:
        fail(
            f"Missing canonical parts ({len(missing)}/{PART_COUNT}): "
            + ", ".join(missing)
        )

    chunks: list[str] = []
    for index in range(PART_COUNT):
        path = output_dir / part_name(index)
        chunk = path.read_text(encoding="ascii").strip()
        expected = expected_part_length(index)
        if len(chunk) != expected:
            fail(
                f"{path.name} length mismatch: got={len(chunk)} expected={expected}"
            )
        chunks.append(chunk)

    encoded = "".join(chunks)
    if len(encoded) != EXPECTED_BASE64_LENGTH:
        fail(
            f"Combined Base64 mismatch: got={len(encoded)} "
            f"expected={EXPECTED_BASE64_LENGTH}"
        )

    try:
        raw = base64.b64decode(encoded, validate=True)
    except Exception as exc:
        fail(f"Strict Base64 decode failed: {exc}")

    validate_source(raw)

    manifest_path = output_dir / MANIFEST_NAME
    if manifest_path.is_file():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if manifest.get("sha256_raw") != EXPECTED_SHA256:
            fail("Manifest raw SHA256 does not match locked source SHA256.")
        if manifest.get("part_count") != PART_COUNT:
            fail("Manifest part_count does not match locked part count.")

    tails = sorted(output_dir.glob("canyon_final_q95_tail*.txt"))
    if tails:
        fail(
            "Temporary tail files still exist after canonical build: "
            + ", ".join(path.name for path in tails)
        )

    print(
        "FINAL CANYON CHUNKS VERIFIED: "
        f"{PART_COUNT} parts / {len(raw)} bytes / "
        f"SHA256=OK / {EXPECTED_WIDTH}x{EXPECTED_HEIGHT} RGBA"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build/verify the locked TinyFisher final canyon payload."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    build_parser = subparsers.add_parser("build", help="Validate source and rebuild all 41 chunks.")
    build_parser.add_argument("source", type=Path, help="Exact approved canyon_q95.webp")
    build_parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"Chunk directory (default: {DEFAULT_OUTPUT_DIR})",
    )

    verify_parser = subparsers.add_parser("verify", help="Verify existing canonical 41 chunks.")
    verify_parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"Chunk directory (default: {DEFAULT_OUTPUT_DIR})",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.command == "build":
            build_chunks(args.source.resolve(), args.output_dir.resolve())
        elif args.command == "verify":
            verify_chunks(args.output_dir.resolve())
        else:
            fail(f"Unknown command: {args.command}")
    except CanyonBuildError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
