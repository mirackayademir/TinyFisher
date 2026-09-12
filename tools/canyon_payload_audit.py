#!/usr/bin/env python3
"""Audit TinyFisher's final canyon payload without modifying files.

The current repository intentionally contains a partial transfer of the locked
final WebP. Individual transport files may end in the middle of a Base64 quartet,
so validation is performed on the reconstructed stream, not on each file as if
it were an independent Base64 document.

Usage:
    python tools/canyon_payload_audit.py
"""

from __future__ import annotations

import base64
import hashlib
import re
import struct
import sys
from pathlib import Path

EXPECTED_PART_COUNT = 41
EXPECTED_CHUNK_BASE64_LENGTH = 16_000
EXPECTED_BASE64_LENGTH = 642_596
EXPECTED_RAW_BYTES = 481_946
EXPECTED_WIDTH = 1226
EXPECTED_HEIGHT = 1283
EXPECTED_SHA256 = "b00865a0d42d6488159f9ecf4cbde30df86873d96036f6630d548ec68f429679"

REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = REPO_ROOT / "assets" / "environment" / "terrain" / "runtime_data_final"

PART_RE = re.compile(r"^canyon_final_q95_part(\d{2})\.txt$")
TAIL_RE = re.compile(r"^canyon_final_q95_tail(\d{2})\.txt$")
BASE64_TEXT_RE = re.compile(r"^[A-Za-z0-9+/=]+$")


class AuditError(RuntimeError):
    pass


def read_transport_text(path: Path) -> str:
    try:
        text = path.read_text(encoding="ascii").strip()
    except Exception as exc:
        raise AuditError(f"Cannot read {path.name}: {exc}") from exc

    if not text:
        raise AuditError(f"Empty canyon payload file: {path.name}")
    if BASE64_TEXT_RE.fullmatch(text) is None:
        raise AuditError(f"Non-Base64 character found in {path.name}")
    return text


def collect_transport_files() -> tuple[list[tuple[int, Path, str]], list[tuple[int, Path, str]]]:
    if not DATA_DIR.is_dir():
        raise AuditError(f"Data directory missing: {DATA_DIR}")

    parts: list[tuple[int, Path, str]] = []
    tails: list[tuple[int, Path, str]] = []

    for path in sorted(DATA_DIR.iterdir()):
        if not path.is_file():
            continue

        part_match = PART_RE.match(path.name)
        if part_match:
            parts.append((int(part_match.group(1)), path, read_transport_text(path)))
            continue

        tail_match = TAIL_RE.match(path.name)
        if tail_match:
            tails.append((int(tail_match.group(1)), path, read_transport_text(path)))

    parts.sort(key=lambda item: item[0])
    tails.sort(key=lambda item: item[0])
    return parts, tails


def require_contiguous(items: list[tuple[int, Path, str]], label: str) -> None:
    if not items:
        return

    actual = [item[0] for item in items]
    if len(actual) != len(set(actual)):
        raise AuditError(f"Duplicate {label} index detected: {actual}")

    expected = list(range(actual[-1] + 1))
    if actual != expected:
        raise AuditError(f"{label} indexes are not contiguous from 00: {actual}")


def inspect_webp_prefix(raw: bytes) -> dict[str, object]:
    info: dict[str, object] = {
        "riff_ok": False,
        "declared_bytes": None,
        "vp8x_seen": False,
        "width": None,
        "height": None,
        "alpha_flag": None,
        "alph_seen": False,
        "alph_complete": False,
        "alph_size": None,
    }

    if len(raw) < 12:
        return info
    if raw[:4] != b"RIFF" or raw[8:12] != b"WEBP":
        raise AuditError("Decoded payload prefix is not RIFF/WEBP.")

    info["riff_ok"] = True
    info["declared_bytes"] = struct.unpack_from("<I", raw, 4)[0] + 8

    pos = 12
    while pos + 8 <= len(raw):
        fourcc = raw[pos : pos + 4]
        chunk_size = struct.unpack_from("<I", raw, pos + 4)[0]
        payload_start = pos + 8
        payload_end = payload_start + chunk_size

        if fourcc == b"VP8X":
            info["vp8x_seen"] = True
            if chunk_size >= 10 and payload_end <= len(raw):
                payload = raw[payload_start:payload_end]
                info["alpha_flag"] = bool(payload[0] & 0x10)
                info["width"] = 1 + int.from_bytes(payload[4:7], "little")
                info["height"] = 1 + int.from_bytes(payload[7:10], "little")

        if fourcc == b"ALPH":
            info["alph_seen"] = True
            info["alph_size"] = chunk_size
            info["alph_complete"] = payload_end <= len(raw)

        if payload_end > len(raw):
            break
        pos = payload_end + (chunk_size & 1)

    return info


def validate_prefix(info: dict[str, object]) -> None:
    declared = info["declared_bytes"]
    if declared is not None and declared != EXPECTED_RAW_BYTES:
        raise AuditError(
            f"RIFF declared size mismatch: got={declared} expected={EXPECTED_RAW_BYTES}"
        )

    width = info["width"]
    height = info["height"]
    if width is not None and height is not None:
        if (width, height) != (EXPECTED_WIDTH, EXPECTED_HEIGHT):
            raise AuditError(
                f"VP8X canvas mismatch: got={width}x{height} "
                f"expected={EXPECTED_WIDTH}x{EXPECTED_HEIGHT}"
            )

    if info["alpha_flag"] is False:
        raise AuditError("VP8X alpha flag is not set.")


def main() -> int:
    try:
        parts, tails = collect_transport_files()
        require_contiguous(parts, "part")
        require_contiguous(tails, "tail")

        canonical_chars = sum(len(text) for _, _, text in parts)
        tail_chars = sum(len(text) for _, _, text in tails)
        combined = "".join(text for _, _, text in parts) + "".join(text for _, _, text in tails)
        total_chars = len(combined)

        if total_chars > EXPECTED_BASE64_LENGTH:
            raise AuditError(
                f"Payload exceeds locked Base64 size: got={total_chars} "
                f"expected<={EXPECTED_BASE64_LENGTH}"
            )

        if "=" in combined[:-2]:
            raise AuditError("Base64 padding appears before the end of the reconstructed stream.")

        decodable_chars = total_chars - (total_chars % 4)
        try:
            raw_prefix = (
                base64.b64decode(combined[:decodable_chars], validate=True)
                if decodable_chars
                else b""
            )
        except Exception as exc:
            raise AuditError(f"Reconstructed Base64 prefix is invalid: {exc}") from exc

        info = inspect_webp_prefix(raw_prefix)
        validate_prefix(info)

        missing_chars = EXPECTED_BASE64_LENGTH - total_chars
        coverage = total_chars / EXPECTED_BASE64_LENGTH * 100.0
        raw_missing_estimate = EXPECTED_RAW_BYTES - len(raw_prefix)

        print("=== TinyFisher Final Canyon Payload Audit ===")
        print(f"canonical files: {len(parts)}/{EXPECTED_PART_COUNT}")
        print(f"temporary tail files: {len(tails)}")
        print(f"canonical chars: {canonical_chars}")
        print(f"tail chars: {tail_chars}")
        print(f"combined Base64: {total_chars}/{EXPECTED_BASE64_LENGTH} ({coverage:.2f}%)")
        print(f"missing Base64 chars: {missing_chars}")
        print(f"decodable raw prefix: {len(raw_prefix)}/{EXPECTED_RAW_BYTES} bytes")
        print(f"estimated missing raw bytes: {raw_missing_estimate}")
        print(f"RIFF header: {'OK' if info['riff_ok'] else 'not available'}")

        if info["declared_bytes"] is not None:
            print(f"RIFF declared bytes: {info['declared_bytes']}")
        if info["vp8x_seen"]:
            print(
                f"VP8X: {info['width']}x{info['height']} "
                f"alpha={'YES' if info['alpha_flag'] else 'NO'}"
            )
        if info["alph_seen"]:
            print(
                f"ALPH: size={info['alph_size']} "
                f"complete={'YES' if info['alph_complete'] else 'NO'}"
            )

        canonical_complete = len(parts) == EXPECTED_PART_COUNT and not tails
        if canonical_complete:
            expected_lengths = [EXPECTED_CHUNK_BASE64_LENGTH] * (EXPECTED_PART_COUNT - 1)
            expected_lengths.append(
                EXPECTED_BASE64_LENGTH
                - EXPECTED_CHUNK_BASE64_LENGTH * (EXPECTED_PART_COUNT - 1)
            )
            actual_lengths = [len(text) for _, _, text in parts]
            if actual_lengths != expected_lengths:
                raise AuditError("Canonical 41-part set exists but chunk lengths are wrong.")
            if total_chars != EXPECTED_BASE64_LENGTH:
                raise AuditError("Canonical 41-part set exists but total Base64 length is wrong.")

            try:
                raw_full = base64.b64decode(combined, validate=True)
            except Exception as exc:
                raise AuditError(f"Canonical full Base64 decode failed: {exc}") from exc

            if len(raw_full) != EXPECTED_RAW_BYTES:
                raise AuditError(
                    f"Canonical raw size mismatch: got={len(raw_full)} expected={EXPECTED_RAW_BYTES}"
                )

            actual_sha = hashlib.sha256(raw_full).hexdigest()
            if actual_sha != EXPECTED_SHA256:
                raise AuditError(
                    f"Canonical SHA256 mismatch: got={actual_sha} expected={EXPECTED_SHA256}"
                )

            print("state: CANONICAL 41-PART SET VERIFIED / FULL SHA256=OK")
        else:
            print("state: PARTIAL TRANSFER (known blocker: exact source is not available)")

        print(f"locked final SHA256: {EXPECTED_SHA256}")
        return 0
    except AuditError as exc:
        print(f"AUDIT ERROR: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"AUDIT ERROR (unexpected): {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
