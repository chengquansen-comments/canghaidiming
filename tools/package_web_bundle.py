#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

REQUIRED_SUFFIXES = [".html", ".js", ".wasm", ".pck"]


def validate_bundle(root: Path) -> None:
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"Bundle directory not found: {root}")
    files = [p for p in root.iterdir() if p.is_file()]
    suffixes = {p.suffix for p in files}
    missing = [suffix for suffix in REQUIRED_SUFFIXES if suffix not in suffixes]
    if missing:
        raise SystemExit("Missing required web build files: %s" % ", ".join(missing))
    if not (root / "index.html").exists():
        raise SystemExit("Missing index.html")


def pack_bundle(root: Path, output_zip: Path) -> None:
    if output_zip.exists():
        output_zip.unlink()
    output_zip.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output_zip, "w", compression=ZIP_DEFLATED) as zf:
        for path in sorted(root.iterdir()):
            if not path.is_file():
                continue
            zf.write(path, arcname=path.name)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", nargs="?", default="build/web")
    parser.add_argument("output_zip", nargs="?", default=None)
    args = parser.parse_args()

    root = Path(args.bundle_dir).resolve()
    output_zip = Path(args.output_zip).resolve() if args.output_zip else root.with_suffix(".zip")

    validate_bundle(root)
    pack_bundle(root, output_zip)
    print(f"[web-package] packaged: {output_zip}")


if __name__ == "__main__":
    main()
