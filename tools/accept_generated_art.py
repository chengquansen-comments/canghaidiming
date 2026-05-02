#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import shutil
from pathlib import Path

from art_asset_pipeline import Image, load_manifest, normalize_repo_path, ok, rel, update_manifest_status
from create_art_asset_task import derive_asset_row, load_prompt_entry, upsert_asset_row


GENERATED_IMAGES_ROOT = Path.home() / ".codex" / "generated_images"


def fail(message: str) -> None:
    raise SystemExit(f"[accept-generated-art] ERROR: {message}")


def note(enabled: bool, message: str) -> None:
    if enabled:
        print(f"[accept-generated-art] {message}")


def find_manifest_row(asset_id: str) -> dict[str, str] | None:
    fieldnames, rows, _ = load_manifest()
    if "asset_id" not in fieldnames:
        fail("tables/art_asset_manifest.tsv is missing asset_id")
    for row in rows:
        if row.get("asset_id", "").strip() == asset_id:
            return row
    return None


def ensure_asset_task(asset_id: str, verbose: bool) -> dict[str, str]:
    row = find_manifest_row(asset_id)
    if row is not None:
        return row
    prompt_row = load_prompt_entry(asset_id)
    asset_row = derive_asset_row(prompt_row)
    action, _ = upsert_asset_row(asset_row, update=False)
    note(verbose, f"{action} asset task for {asset_id}")
    return asset_row


def find_latest_generated_png() -> Path:
    if not GENERATED_IMAGES_ROOT.exists():
        fail(f"missing generated image root: {GENERATED_IMAGES_ROOT}")
    candidates = list(GENERATED_IMAGES_ROOT.rglob("ig_*.png"))
    if not candidates:
        fail(f"no generated PNG files found under {GENERATED_IMAGES_ROOT}")
    return max(candidates, key=lambda path: path.stat().st_mtime_ns)


def validate_image(path: Path) -> tuple[int, int, str]:
    if not path.exists():
        fail(f"missing image: {path}")
    if path.stat().st_size <= 0:
        fail(f"image is empty: {path}")
    with Image.open(path) as image:
        width, height = image.size
        mode = image.mode
        image.load()
    if width <= 0 or height <= 0:
        fail(f"image has invalid size: {path}")
    return width, height, mode


def copy_atomic(source_path: Path, destination_path: Path) -> None:
    destination_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = destination_path.with_name(f".{destination_path.name}.tmp")
    if temp_path.exists():
        temp_path.unlink()
    try:
        shutil.copyfile(source_path, temp_path)
        validate_image(temp_path)
        os.replace(temp_path, destination_path)
    finally:
        if temp_path.exists():
            temp_path.unlink()


def accept_generated_art(asset_id: str, source: str | None = None, use_latest: bool = False, verbose: bool = True) -> tuple[str, str]:
    row = ensure_asset_task(asset_id, verbose)
    if source:
        source_image = normalize_repo_path(source)
    elif use_latest:
        source_image = find_latest_generated_png()
    else:
        fail("provide --source or --latest")
    source_width, source_height, source_mode = validate_image(source_image)

    destination_path = normalize_repo_path(row.get("source_path", ""))
    if str(destination_path) == "":
        fail(f"asset {asset_id} is missing source_path")
    copy_atomic(source_image, destination_path)
    dest_width, dest_height, dest_mode = validate_image(destination_path)
    previous, current = update_manifest_status(asset_id, "SOURCE_READY")

    note(
        verbose,
        f"accepted {source_image} -> {rel(destination_path)} "
        f"{source_width}x{source_height} {source_mode} => {dest_width}x{dest_height} {dest_mode}",
    )
    return previous, current


def main() -> int:
    parser = argparse.ArgumentParser(description="Accept a generated PNG into art_reference/final for one asset.")
    parser.add_argument("asset_id", help="tables/art_asset_manifest.tsv asset_id")
    source_group = parser.add_mutually_exclusive_group(required=True)
    source_group.add_argument("--source", help="Explicit generated PNG path")
    source_group.add_argument("--latest", action="store_true", help="Use the most recently modified generated PNG under ~/.codex/generated_images")
    parser.add_argument("--quiet", action="store_true", help="Only print the final status line")
    args = parser.parse_args()

    verbose = not args.quiet
    previous, current = accept_generated_art(args.asset_id, source=args.source, use_latest=args.latest, verbose=verbose)
    ok(f"{args.asset_id}: {previous or '<empty>'} -> {current}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
