#!/usr/bin/env python3
"""Audit TinyFisher's final canyon payload without modifying any files.

This script is intentionally safe to run while the source transfer is partial.
It reports canonical part/tail coverage, validates Base64 syntax, inspects the
available WebP prefix, and exits non-zero only for corruption/inconsistency.

Usage:
    python tools/canyon_payload_audit.py
"""

from __future__ import annotations

import base64
import re
import struct
import sys
from pathlib import Path

PART_PREFIX = "canyon_final_q95_part"
TAIL_PREFIX = "canyon_final_q95_tail"
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


class AuditError(RuntimeError):
    pass


def _read_ascii(path: Path) -> str:
    try:
        text = path.read_text(encoding="ascii").strip()
    except Exception as exc:
        raise AuditError(f"Cannot read {path.name}: {exc}") from exc
    if not text:
        raise AuditError(f"Empty canyon payload file: {path.name}")
    try:
        base64.b64decode(text + ("=" * ((-len(text)) % 4)), validate=True)
    except Exception as exc:
        raise AuditError(f"Invalid Base64 characters in {path.name}: {exc}") from exc
    return text


def _collect() -> tuple[list[tuple[int, Path, str]], list[tuple[int, Path, str]]]:
    if not DATA_DIR.is_dir():
        raise AuditError(f"Data directory missing: {DATA_DIR}")

    parts: list[tuple[int, Path, str]] = []
    tails: list[tuple[int, Path, str]] = []
    seen_part: set[int] = set()
    seen_tail: set[int] = set()

    for path in sorted(DATA_DIR.iterdir()):
        if not path.is_file():
            continue
        part_match = PART_RE.match(path.name)
        tail_match = TAIL_RE.match(path.name)
        if part_match:
            index = int(part_match.group(1))
            if index in seen_part:
                raise AuditError(f"Duplicate canonical part index: {index:02d}")
            seen_part.add(index)
            parts.append((index, path, _read_ascii(path)))
        elif tail_match:
            index = int(tail_match.group(1))
            if index in seen_tail:
                raise AuditError(f"Duplicate temporary tail index: {index:02d}")
            seen_tail.add(index)
            tails.append((index, path, _read_ascii(path)))

    parts.sort(key=lambda item: item[0])
    tails.sort(key=lambda item: item[0])
    return parts, tails


def _validate_index_continuity(items: list[tuple[int, Path, str]], label: str) -> None:
    if not items:
        return
    expected = list(range(items[-1][0] + 1))
    actual = [item[0] for item in items]
    if actual != expected:
        raise AuditError(f"{label} indexes are not contiguous from 00: {actual}")


def _inspect_prefix(raw_prefix: bytes) -> dict[str, object]:
    result: dict[str, object] = {
        "riff_ok": False,
        "declared_bytes": None,
        "vp8x_seen": False,
        "width": None,
        "height": None,
        "alpha_flag": None,
        "alph_chunk_seen": False,
        "alph_chunk_complete": False,
        "alph_chunk_size": None,
    }

    if len(raw_prefix) < 12:
        return result
    if raw_prefix[:4] != b"RIFF" or raw_prefix[8:12] != b"WEBP":
        raise AuditError("Decoded prefix does not begin with RIFF/WEBP.")

    result["riff_ok"] = True
    result["declared_bytes"] = struct.unpack_from("<I", raw_prefix, 4)[0] + 8

    pos = 12
    while pos + 8 <= len(raw_prefix):
        fourcc = raw_prefix[pos : pos + 4]
        chunk_size = struct.unpack_from("<I", raw_prefix, pos + 4)[0]
        payload_start = pos + 8
        payload_end = payload_start + chunk_size

        if fourcc == b"VP8X":
            result["vp8x_seen"] = True
            if payload_end <= len(raw_prefix) and chunk_size >= 10:
                payload = raw_prefix[payload_start:payload_end]
                result["alpha_flag"] = bool(payload[0] & 0x10)
                result["width"] = 1 + int.from_bytes(payload[4:7], "little")
                result["height"] = 1 + int.from_bytes(payload[7:10], "little")

        if fourcc == b"ALPH":
            result["alph_chunk_seen"] = True
            result["alph_chunk_size"] = chunk_size
            result["alph_chunk_complete"] = payload_end <= len(raw_prefix)

        if payload_end > len(raw_prefix):
            break
        pos = payload_end + (chunk_size & 1)

    return result


def main() -> int:
    try:
        parts, tails = _collect()
        _validate_index_continuity(parts, "part")
        _validate_index_continuity(tails, "tail")

        canonical_chars = sum(len(item[2]) for item in parts)
        tail_chars = sum(len(item[2]) for item in tails)
        total_chars = canonical_chars + tail_chars

        if total_chars > EXPECTED_BASE64_LENGTH:
            raise AuditError(
                f"Payload exceeds locked Base64 size: {total_chars} > {EXPECTED_BASE64_LENGTH}"
            )

        combined = "".join(item[2] for item in parts) + "".join(item[2] for item in tails)
        decodable_chars = len(combined) - (len(combined) % 4)
        raw_prefix = base64.b64decode(combined[:decodable_chars], validate=True) if decodable_chars else b""
        prefix = _inspect_prefix(raw_prefix)

        declared = prefix["declared_bytes"]
        if declared is not None and declared != EXPECTED_RAW_BYTES:
            raise AuditError(
                f"RIFF declares unexpected file size: {declared} != {EXPECTED_RAW_BYTES}"
            )
        if prefix["width"] is not None and prefix["height"] is not None:
            if (prefix["width"], prefix["height"]) != (EXPECTED_WIDTH, EXPECTED_HEIGHT):
                raise AuditError(
                    "VP8X canvas mismatch: "
                    f"{prefix['width']}x{prefix['height']} != {EXPECTED_WIDTH}x{EXPECTED_HEIGHT}"
                )
        if prefix["alpha_flag"] is False:
            raise AuditError("VP8X alpha flag is not set on the transferred source prefix.")

        missing_chars = EXPECTED_BASE64_LENGTH - total_chars
        coverage = (total_chars / EXPECTED_BASE64_LENGTH * 100.0) if EXPECTED_BASE64_LENGTH else 0.0
        raw_missing_estimate = EXPECTED_RAW_BYTES - len(raw_prefix)

        print("=== TinyFisher Final Canyon Payload Audit ===")
        print(f"directory: {DATA_DIR}")
        print(f"canonical files: {len(parts)}/{EXPECTED_PART_COUNT}")
        print(f"temporary tail files: {len(tails)}")
        print(f"canonical chars: {canonical_chars}")
        print(f"tail chars: {tail_chars}")
        print(f"combined Base64: {total_chars}/{EXPECTED_BASE64_LENGTH} ({coverage:.2f}%)")
        print(f"missing Base64 chars: {missing_chars}")
        print(f"decodable raw prefix: {len(raw_prefix)}/{EXPECTED_RAW_BYTES} bytes")
        print(f"estimated missing raw bytes: {raw_missing_estimate}")
        print(f"RIFF header: {'OK' if prefix['riff_ok'] else 'not available yet'}")
        if prefix["declared_bytes"] is not None:
            print(f"RIFF declared bytes: {prefix['declared_bytes']}")
        if prefix["vp8x_seen"]:
            print(
                "VP8X: "
                f"{prefix['width']}x{prefix['height']} "
                f"alpha={'YES' if prefix['alpha_flag'] else 'NO'}"
            )
        if prefix["alph_chunk_seen"]:
            print(
                "ALPH chunk: "
                f"size={prefix['alph_chunk_size']} "
                f"complete={'YES' if prefix['alph_chunk_complete'] else 'NO'}"
            )

        canonical_complete = len(parts) == EXPECTED_PART_COUNT and not tails
        if canonical_complete:
            expected_lengths = [EXPECTED_CHUNK_BASE64_LENGTH] * (EXPECTED_PART_COUNT - 1)
            expected_lengths.append(
                EXPECTED_BASE64_LENGTH - EXPECTED_CHUNK_BASE64_LENGTH * (EXPECTED_PART_COUNT - 1)
            )
            actual_lengths = [len(item[2]) for item in parts]
            if actual_lengths != expected_lengths:
                raise AuditError(
                    f"41 canonical files exist but chunk lengths are wrong: {actual_lengths}"
                )
            if total_chars != EXPECTED_BASE64_LENGTH:
                raise AuditError(
                    f"41 canonical files exist but total length is {total_chars}, expected {EXPECTED_BASE64_LENGTH}"
                )
            print("state: CANONICAL 41-PART SET PRESENT; run canyon_final_builder.py verify")
        else:
            print("state: PARTIAL TRANSFER (expected until exact source is restored)")

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
