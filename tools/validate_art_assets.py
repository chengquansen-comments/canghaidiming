#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"[art-assets] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def ok(message: str) -> None:
    print(f"[art-assets] OK: {message}")


def run_bundle_validator(path: Path) -> None:
    tool = Path(__file__).resolve().parent / "validate_actor_bundle.py"
    if not tool.exists():
        fail(f"missing tool: {tool}")
    result = subprocess.run([sys.executable, str(tool), str(path)], text=True)
    if result.returncode != 0:
        fail(f"actor bundle validation failed: {path}")


def discover_actor_dirs(root: Path) -> list[Path]:
    if not root.exists():
        fail(f"actor root not found: {root}")
    if not root.is_dir():
        fail(f"actor root is not a directory: {root}")
    dirs: list[Path] = []
    for child in sorted(root.iterdir()):
        if child.is_dir() and list(child.glob("*.meta.json")):
            dirs.append(child)
    return dirs


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate art assets for the Web visual pipeline.")
    parser.add_argument("--actors-root", default="assets/pixel_battle/actors")
    parser.add_argument("--allow-empty", action="store_true", help="Do not fail when no actor bundles exist yet.")
    args = parser.parse_args()

    root = Path(args.actors_root)
    actor_dirs = discover_actor_dirs(root)
    if not actor_dirs:
        if args.allow_empty:
            ok(f"no actor bundles found under {root}; allowed")
            return
        fail(f"no actor bundles found under {root}")

    for actor_dir in actor_dirs:
        run_bundle_validator(actor_dir)
    ok(f"validated {len(actor_dirs)} actor bundle(s)")


if __name__ == "__main__":
    main()
