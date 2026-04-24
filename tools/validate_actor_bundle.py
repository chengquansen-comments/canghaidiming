#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

MIN_REQUIRED_ANIMATIONS = ["idle", "move_forward", "attack_light", "guard", "hit", "break"]
RECOMMENDED_ANIMATIONS = ["move_back", "attack_heavy", "focus", "victory", "defeat"]


def fail(message: str) -> None:
    print(f"[actor-bundle] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def warn(message: str) -> None:
    print(f"[actor-bundle] WARN: {message}")


def ok(message: str) -> None:
    print(f"[actor-bundle] OK: {message}")


def run_tool(script_name: str, meta_path: Path) -> None:
    tool = Path(__file__).resolve().parent / script_name
    if not tool.exists():
        fail(f"missing tool: {tool}")
    result = subprocess.run([sys.executable, str(tool), str(meta_path)], text=True)
    if result.returncode != 0:
        fail(f"{script_name} failed for {meta_path}")


def load_meta(meta_path: Path) -> dict[str, Any]:
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"failed to read JSON {meta_path}: {exc}")
    if not isinstance(meta, dict):
        fail(f"meta root must be object: {meta_path}")
    return meta


def score_bundle(meta: dict[str, Any]) -> tuple[str, list[str]]:
    animations = meta.get("animations", {})
    if not isinstance(animations, dict):
        return "C", ["animations missing or invalid"]

    issues: list[str] = []
    missing_min = [name for name in MIN_REQUIRED_ANIMATIONS if name not in animations]
    missing_recommended = [name for name in RECOMMENDED_ANIMATIONS if name not in animations]
    if missing_min:
        issues.append("missing minimum animations: " + ", ".join(missing_min))
        return "C", issues

    attack_count = len([name for name in animations if name.startswith("attack")])
    if attack_count < 1:
        issues.append("no attack animation")
        return "C", issues

    if missing_recommended:
        issues.append("missing recommended animations: " + ", ".join(missing_recommended))
        return "A", issues

    return "S", issues


def validate_bundle(actor_dir: Path) -> None:
    if not actor_dir.exists() or not actor_dir.is_dir():
        fail(f"actor directory not found: {actor_dir}")
    meta_files = sorted(actor_dir.glob("*.meta.json"))
    if not meta_files:
        fail(f"no *.meta.json found in {actor_dir}")
    if len(meta_files) > 1:
        warn(f"multiple meta files found in {actor_dir}; validating all")

    for meta_path in meta_files:
        print(f"[actor-bundle] validating {meta_path}")
        run_tool("validate_actor_meta.py", meta_path)
        run_tool("validate_actor_sheet.py", meta_path)
        meta = load_meta(meta_path)
        grade, issues = score_bundle(meta)
        role_id = meta.get("role_id", meta_path.stem)
        animations = meta.get("animations", {})
        animation_count = len(animations) if isinstance(animations, dict) else 0
        print("[actor-bundle] summary")
        print(f"  role_id: {role_id}")
        print(f"  grade: {grade}")
        print(f"  animations: {animation_count}")
        if isinstance(animations, dict):
            print("  animation_names: " + ", ".join(sorted(animations.keys())))
        if issues:
            for issue in issues:
                warn(issue)
        ok(f"bundle validated: {actor_dir}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate one or more actor animation bundles.")
    parser.add_argument("paths", nargs="+", help="actor directories or meta.json paths")
    args = parser.parse_args()

    for raw in args.paths:
        path = Path(raw)
        if path.is_file() and path.name.endswith(".meta.json"):
            validate_bundle(path.parent)
        else:
            validate_bundle(path)


if __name__ == "__main__":
    main()
