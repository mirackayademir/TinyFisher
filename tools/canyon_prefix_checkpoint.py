#!/usr/bin/env python3
"""Verify the already-transferred canyon prefix against the approved source."""

from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

CHECKPOINT_CHARS = 331_952
CHECKPOINT_SHA256 = "60493e64a56aff439ec8b2e55d93bf3700298f3431cd79d22e35fbc268af9eef"

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "assets" / "environment" / "terrain" / "runtime_data_final"
PART_RE = re.compile(r"^canyon_final_q95_part(\d{2})\.txt$")
TAIL_RE = re.compile(r"^canyon_final_q95_tail(\d{2})\.txt$")


def collect(pattern: re.Pattern[str]) -> list[tuple[int, str]]:
    found: list[tuple[int, str]] = []
    for path in DATA_DIR.iterdir():
        if not path.is_file():
            continue
        match = pattern.match(path.name)
        if match:
            found.append((int(match.group(1)), path.read_text(encoding="ascii").strip()))
    found.sort(key=lambda item: item[0])
    return found


def main() -> int:
    parts = collect(PART_RE)
    tails = collect(TAIL_RE)
    stream = "".join(text for _, text in parts) + "".join(text for _, text in tails)

    if len(stream) < CHECKPOINT_CHARS:
        print(
            f"CHECKPOINT ERROR: stream too short: {len(stream)} < {CHECKPOINT_CHARS}",
            file=sys.stderr,
        )
        return 1

    prefix = stream[:CHECKPOINT_CHARS]
    actual = hashlib.sha256(prefix.encode("ascii")).hexdigest()
    if actual != CHECKPOINT_SHA256:
        print(
            "CHECKPOINT ERROR: existing canyon prefix differs from approved source\n"
            f"got={actual}\nexpected={CHECKPOINT_SHA256}",
            file=sys.stderr,
        )
        return 1

    print(
        "CANYON PREFIX CHECKPOINT VERIFIED: "
        f"{CHECKPOINT_CHARS} chars / SHA256={CHECKPOINT_SHA256}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
