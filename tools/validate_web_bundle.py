#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

REQUIRED_SUFFIXES = [".html", ".js", ".wasm", ".pck"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", nargs="?", default="build/web")
    args = parser.parse_args()

    root = Path(args.bundle_dir).resolve()
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"Bundle directory not found: {root}")

    files = [p for p in root.iterdir() if p.is_file()]
    suffixes = {p.suffix for p in files}
    missing = [suffix for suffix in REQUIRED_SUFFIXES if suffix not in suffixes]
    if missing:
        raise SystemExit("Missing required web bundle files: %s" % ", ".join(missing))

    index_file = root / "index.html"
    if not index_file.exists():
        raise SystemExit("Missing index.html")

    print(f"[web-bundle] validated: {root}")


if __name__ == "__main__":
    main()
