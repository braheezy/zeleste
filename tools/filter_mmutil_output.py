#!/usr/bin/env python3
"""Run mmutil while hiding its unconditional file-open success messages."""

from __future__ import annotations

import subprocess
import sys


FILTERED_PREFIXES = (
    "File opened for reading:",
    "File opened for writing:",
)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: filter_mmutil_output.py <mmutil> [args...]", file=sys.stderr)
        return 2

    result = subprocess.run(sys.argv[1:], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if line.startswith(FILTERED_PREFIXES):
            continue
        print(line)
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
