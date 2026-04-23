#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

TRACKED_SUFFIXES = {".html", ".js", ".wasm", ".pck"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", nargs="?", default="build/web")
    parser.add_argument("--output", default="manifest.json")
    args = parser.parse_args()

    root = Path(args.bundle_dir).resolve()
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"Bundle directory not found: {root}")

    files = []
    total_size = 0
    for path in sorted(root.iterdir()):
        if not path.is_file() or path.suffix not in TRACKED_SUFFIXES:
            continue
        size = path.stat().st_size
        total_size += size
        files.append({
            "name": path.name,
            "suffix": path.suffix,
            "size_bytes": size,
        })

    manifest = {
        "bundle_dir": str(root),
        "total_size_bytes": total_size,
        "files": files,
    }

    output_path = root / args.output
    output_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[web-bundle] manifest written: {output_path}")


if __name__ == "__main__":
    main()
