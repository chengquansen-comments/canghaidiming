#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

DEFAULT_TOTAL_BUDGET_MB = 300.0
DEFAULT_PCK_BUDGET_MB = 240.0
DEFAULT_WASM_BUDGET_MB = 60.0


def size_mb(path: Path) -> float:
    return path.stat().st_size / (1024.0 * 1024.0)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", nargs="?", default="build/web")
    parser.add_argument("--total-budget-mb", type=float, default=DEFAULT_TOTAL_BUDGET_MB)
    parser.add_argument("--pck-budget-mb", type=float, default=DEFAULT_PCK_BUDGET_MB)
    parser.add_argument("--wasm-budget-mb", type=float, default=DEFAULT_WASM_BUDGET_MB)
    args = parser.parse_args()

    root = Path(args.bundle_dir).resolve()
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"Bundle directory not found: {root}")

    files = [p for p in root.iterdir() if p.is_file()]
    total_size_mb = sum(p.stat().st_size for p in files) / (1024.0 * 1024.0)
    wasm_files = [p for p in files if p.suffix == ".wasm"]
    pck_files = [p for p in files if p.suffix == ".pck"]

    if total_size_mb > args.total_budget_mb:
        raise SystemExit(f"Total bundle size {total_size_mb:.2f} MB exceeds budget {args.total_budget_mb:.2f} MB")

    for path in wasm_files:
        current = size_mb(path)
        if current > args.wasm_budget_mb:
            raise SystemExit(f"WASM file {path.name} is {current:.2f} MB, exceeds budget {args.wasm_budget_mb:.2f} MB")

    for path in pck_files:
        current = size_mb(path)
        if current > args.pck_budget_mb:
            raise SystemExit(f"PCK file {path.name} is {current:.2f} MB, exceeds budget {args.pck_budget_mb:.2f} MB")

    print(
        "[web-bundle] budget check passed: total=%.2f MB, wasm<=%.2f MB, pck<=%.2f MB"
        % (total_size_mb, args.wasm_budget_mb, args.pck_budget_mb)
    )


if __name__ == "__main__":
    main()
