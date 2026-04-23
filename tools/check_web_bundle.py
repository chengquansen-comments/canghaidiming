#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

REQUIRED_SUFFIXES = (".html", ".js", ".wasm", ".pck")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", nargs="?", default="build/web", help="exported web bundle directory")
    args = parser.parse_args()

    root = Path(args.bundle_dir).resolve()
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"Web bundle directory not found: {root}")

    missing = []
    for suffix in REQUIRED_SUFFIXES:
        if not any(root.glob(f"*{suffix}")):
            missing.append(suffix)

    if missing:
        print(f"[web-check] missing required artifacts: {', '.join(missing)}", file=sys.stderr)
        raise SystemExit(1)

    index_file = root / "index.html"
    if not index_file.exists():
        print("[web-check] warning: index.html not found by exact name", file=sys.stderr)

    print(f"[web-check] ok: {root}")


if __name__ == "__main__":
    main()
