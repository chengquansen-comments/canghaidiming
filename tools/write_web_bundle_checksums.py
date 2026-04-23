#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

TRACKED_SUFFIXES = {".html", ".js", ".wasm", ".pck", ".json", ".zip"}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", nargs="?", default="build/web")
    parser.add_argument("--zip", dest="zip_path", default=None)
    parser.add_argument("--output", default="checksums.txt")
    args = parser.parse_args()

    root = Path(args.bundle_dir).resolve()
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"Bundle directory not found: {root}")

    tracked_files = []
    for path in sorted(root.iterdir()):
        if path.is_file() and path.suffix in TRACKED_SUFFIXES:
            tracked_files.append(path)

    if args.zip_path:
        zip_path = Path(args.zip_path).resolve()
        if zip_path.exists() and zip_path.is_file():
            tracked_files.append(zip_path)

    lines = []
    for path in tracked_files:
        lines.append(f"{sha256_file(path)}  {path.name}")

    output_path = root / args.output
    output_path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
    print(f"[web-bundle] checksums written: {output_path}")


if __name__ == "__main__":
    main()
