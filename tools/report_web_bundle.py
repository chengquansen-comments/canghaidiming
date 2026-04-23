#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

TRACKED_SUFFIXES = [".html", ".js", ".wasm", ".pck"]


def human_size(num_bytes: int) -> str:
    value = float(num_bytes)
    units = ["B", "KB", "MB", "GB"]
    for unit in units:
        if value < 1024.0 or unit == units[-1]:
            return f"{value:.1f} {unit}"
        value /= 1024.0
    return f"{num_bytes} B"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", nargs="?", default="build/web")
    args = parser.parse_args()

    root = Path(args.bundle_dir).resolve()
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"Bundle directory not found: {root}")

    files = sorted([p for p in root.iterdir() if p.is_file()])
    total_size = sum(p.stat().st_size for p in files)

    print(f"[web-bundle] root: {root}")
    print(f"[web-bundle] total: {human_size(total_size)}")

    for suffix in TRACKED_SUFFIXES:
        matching = [p for p in files if p.suffix == suffix]
        if not matching:
            print(f"[web-bundle] {suffix}: missing")
            continue
        for path in matching:
            print(f"[web-bundle] {path.name}: {human_size(path.stat().st_size)}")


if __name__ == "__main__":
    main()
