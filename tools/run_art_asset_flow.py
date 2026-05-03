#!/usr/bin/env python3
from __future__ import annotations

import argparse
import contextlib
import io
import subprocess
import sys
from pathlib import Path

from art_asset_pipeline import (
    detect_godot_import,
    describe_runtime,
    export_runtime_image,
    get_manifest_entry,
    godot_import_is_stale,
    load_manifest,
    parse_import_destinations,
    update_hook_table,
    update_manifest_status,
    validate_compiled_value,
    validate_hook_table_value,
    validate_runtime_image,
    validate_source_exists,
)
from accept_generated_art import accept_generated_art, ensure_asset_task as ensure_accept_task, find_latest_generated_png
from create_art_asset_task import derive_asset_row, load_prompt_entry, upsert_asset_row
from refresh_art_backlog import refresh as refresh_backlog


ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise SystemExit(f"[run-art-asset-flow] ERROR: {message}")


def note(enabled: bool, message: str) -> None:
    if enabled:
        print(f"[run-art-asset-flow] {message}")


def asset_task_exists(asset_id: str) -> bool:
    _, rows, _ = load_manifest()
    return any(row.get("asset_id", "").strip() == asset_id for row in rows)


def ensure_asset_task(asset_id: str, sync_task: bool, verbose: bool) -> None:
    if asset_task_exists(asset_id):
        if not sync_task:
            return
        prompt_row = load_prompt_entry(asset_id)
        asset_row = derive_asset_row(prompt_row)
        action, _ = upsert_asset_row(asset_row, update=True)
        note(verbose, f"{action} asset task for {asset_id}")
        return
    prompt_row = load_prompt_entry(asset_id)
    asset_row = derive_asset_row(prompt_row)
    action, _ = upsert_asset_row(asset_row, update=False)
    note(verbose, f"{action} asset task for {asset_id}")


def resolve_acceptance(asset_id: str, from_source: str | None, from_latest: bool) -> tuple[Path, Path] | None:
    if not (from_source or from_latest):
        return None
    row = ensure_accept_task(asset_id, verbose=False)
    destination_path = Path(row.get("source_path", "")).expanduser()
    if not destination_path.is_absolute():
        destination_path = ROOT / destination_path
    if from_source:
        source_path = Path(from_source).expanduser()
    else:
        source_path = find_latest_generated_png()
    return source_path.resolve(), destination_path.resolve()


def run_command(argv: list[str], verbose: bool) -> None:
    result = subprocess.run(argv, cwd=ROOT, text=True, capture_output=True)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        command = " ".join(argv)
        fail(f"command failed: {command}\n{detail}")
    if verbose and result.stdout.strip():
        for line in result.stdout.strip().splitlines():
            note(True, line)


def promote_asset(asset_id: str, verbose: bool) -> None:
    _, _, _, row, _ = get_manifest_entry(asset_id)
    source_path, runtime_path, profile = describe_runtime(row)
    validate_source_exists(source_path)
    output = export_runtime_image(source_path, runtime_path, profile)
    note(verbose, f"wrote {runtime_path.relative_to(ROOT)} {output.width}x{output.height} {output.mode}")
    update_hook_table(row, runtime_path)
    previous, current = update_manifest_status(asset_id, "WIRED" if row.get("hook_table", "").strip() else "EXPORTED")
    note(verbose, f"{asset_id}: {previous or '<empty>'} -> {current}")


def validate_asset(asset_id: str, require_import: bool, verbose: bool) -> str:
    _, _, _, row, _ = get_manifest_entry(asset_id)
    _, runtime_path, _ = describe_runtime(row)
    width, height, mode = validate_runtime_image(row, runtime_path)
    validate_hook_table_value(row, runtime_path)
    hook_table = row.get("hook_table", "").strip()
    compiled_path: Path | None = None
    if hook_table:
        compiled_path = validate_compiled_value(row, runtime_path)

    imported, import_path, ctex_matches = detect_godot_import(runtime_path)
    if require_import and not imported:
        fail(f"Godot import artifacts missing for {runtime_path.name}; run with --import")

    target_status = "GODOT_IMPORTED" if imported else "COMPILED"
    previous, current = update_manifest_status(asset_id, target_status)
    note(verbose, f"runtime OK: {runtime_path} {width}x{height} {mode}")
    if compiled_path is not None:
        note(verbose, f"compiled OK: {compiled_path}")
    else:
        note(verbose, "compiled skipped: no hook_table for this asset type")
    if imported:
        note(verbose, f"godot import OK: {import_path} ({len(ctex_matches)} ctex)")
        for destination in parse_import_destinations(import_path):
            note(verbose, destination)
        if godot_import_is_stale(runtime_path, ctex_matches):
            note(verbose, "godot import warning: import artifacts are older than the runtime PNG")
    else:
        note(verbose, "godot import pending")
    note(verbose, f"{asset_id}: {previous or '<empty>'} -> {current}")
    return current


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the standard promote/compile/validate/import flow for one art asset.")
    parser.add_argument("asset_id", help="tables/art_asset_manifest.tsv asset_id")
    parser.add_argument("--import", dest="run_import", action="store_true", help="Run `godot --headless --import --quit` before the final validation pass")
    parser.add_argument("--refresh", action="store_true", help="Refresh tables/art_backlog.tsv after the asset flow succeeds")
    source_group = parser.add_mutually_exclusive_group()
    source_group.add_argument("--from-latest", action="store_true", help="Accept the latest generated PNG into source_path before running the flow")
    source_group.add_argument("--from-source", help="Accept an explicit source PNG into source_path before running the flow")
    parser.add_argument("--print-source", action="store_true", help="Print the resolved source PNG and source_path, then continue unless --dry-run is also set")
    parser.add_argument("--dry-run", action="store_true", help="Resolve inputs and print what would run without changing files")
    parser.add_argument("--quiet", action="store_true", help="Only print the final summary line")
    parser.add_argument("--sync-task", action="store_true", help="Refresh an existing asset task from tables/art_prompt_manifest.tsv before running")
    args = parser.parse_args()

    verbose = not args.quiet
    ensure_asset_task(args.asset_id, args.sync_task, verbose)
    acceptance = resolve_acceptance(args.asset_id, args.from_source, args.from_latest)
    if args.print_source or args.dry_run:
        if acceptance is None:
            print(f"[run-art-asset-flow] {args.asset_id}: source=<unchanged>")
        else:
            source_path, destination_path = acceptance
            print(f"[run-art-asset-flow] {args.asset_id}: source={source_path} -> {destination_path}")
    if args.dry_run:
        print(
            f"[run-art-asset-flow] {args.asset_id}: dry-run import={args.run_import} refresh={args.refresh} sync_task={args.sync_task}"
        )
        return 0
    if args.from_latest or args.from_source:
        accept_generated_art(
            args.asset_id,
            source=args.from_source,
            use_latest=args.from_latest,
            verbose=verbose,
        )
    promote_asset(args.asset_id, verbose)
    run_command([sys.executable, "scripts/compile_tables.py"], verbose)
    validate_asset(args.asset_id, require_import=False, verbose=verbose)

    final_status = "COMPILED"
    if args.run_import:
        run_command(["godot", "--headless", "--import", "--quit"], verbose)
        final_status = validate_asset(args.asset_id, require_import=True, verbose=verbose)
    else:
        final_status = validate_asset(args.asset_id, require_import=False, verbose=verbose)

    if args.refresh:
        if verbose:
            refresh_backlog()
        else:
            with contextlib.redirect_stdout(io.StringIO()):
                refresh_backlog()
        note(verbose, "refreshed art backlog")

    print(f"[run-art-asset-flow] {args.asset_id}: final={final_status}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
