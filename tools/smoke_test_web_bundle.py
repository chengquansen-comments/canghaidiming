#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

REQUIRED_FILES = ["index.html", "manifest.json", "checksums.txt"]
REQUIRED_SUFFIXES = [".js", ".wasm", ".pck"]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", nargs="?", default="build/web")
    parser.add_argument("--zip", dest="zip_path", default=None)
    args = parser.parse_args()

    root = Path(args.bundle_dir).resolve()
    require(root.exists() and root.is_dir(), f"Bundle directory not found: {root}")

    for name in REQUIRED_FILES:
        require((root / name).exists(), f"Missing required file: {name}")

    for suffix in REQUIRED_SUFFIXES:
        require(any(p.suffix == suffix for p in root.iterdir() if p.is_file()), f"Missing required bundle suffix: {suffix}")

    manifest_path = root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest_files = manifest.get("files", [])
    require(isinstance(manifest_files, list) and manifest_files, "Manifest files list is empty")

    manifest_names = set()
    for item in manifest_files:
        name = item.get("name")
        size_bytes = item.get("size_bytes")
        require(isinstance(name, str) and name != "", "Manifest contains invalid file name")
        path = root / name
        require(path.exists(), f"Manifest references missing file: {name}")
        require(path.stat().st_size == size_bytes, f"Manifest size mismatch for: {name}")
        manifest_names.add(name)

    checksum_path = root / "checksums.txt"
    checksum_lines = [line.strip() for line in checksum_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    require(checksum_lines, "checksums.txt is empty")

    checksum_names = set()
    for line in checksum_lines:
        parts = line.split("  ", 1)
        require(len(parts) == 2, f"Invalid checksum line: {line}")
        expected_hash, name = parts
        if name.endswith(".zip") and args.zip_path:
            path = Path(args.zip_path).resolve()
        else:
            path = root / name
        require(path.exists(), f"Checksum references missing file: {name}")
        actual_hash = sha256_file(path)
        require(actual_hash == expected_hash, f"Checksum mismatch for: {name}")
        checksum_names.add(name)

    require(manifest_names.issubset(checksum_names), "Not all manifest files are covered by checksums")
    if args.zip_path:
        zip_name = Path(args.zip_path).name
        require(zip_name in checksum_names, f"Zip output missing from checksums: {zip_name}")

    print(f"[web-bundle] smoke test passed: {root}")


if __name__ == "__main__":
    main()
