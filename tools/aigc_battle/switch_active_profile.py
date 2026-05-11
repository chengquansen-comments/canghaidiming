#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
MECHANICS_DIR = ROOT / "data" / "aigc_battle" / "mechanics"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"
RUNTIME_DIR = ROOT / "data" / "aigc_battle" / "runtime"
LOCK_PATH = RUNTIME_DIR / "active_profile.lock"
ACTIVE_HISTORY_PATH = RUNTIME_DIR / "active_profile_history.jsonl"
SAFE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*$")

REQUIRED_VALIDATION_FLAGS = {
    "ready_for_runtime_export": True,
    "full_sequence_coverage_complete": True,
    "runtime_export_allowed": True,
    "sequence_balance_pass": True,
}
OPTIONAL_TRUE_FLAGS = [
    "deck_card_realm_eligibility_valid",
    "no_card_above_player_wujing_in_deck",
]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="switch active aigc battle profile safely")
    parser.add_argument("profile_id", nargs="?")
    parser.add_argument("--pack")
    args = parser.parse_args(argv[1:])
    if not args.profile_id:
        print("usage: python tools/aigc_battle/switch_active_profile.py <profile_id> [--pack <content_pack_id>]", file=sys.stderr)
        return 1
    switch_active_profile(args.profile_id, args.pack)
    print(f"switched active profile: {args.profile_id}")
    return 0


def switch_active_profile(profile_id: str, pack_id: str | None = None, switch_source: str = 'cli') -> dict[str, Any]:
    pack_id = normalize_pack_id(profile_id, pack_id)
    summary = validate_profile_ready(profile_id, pack_id)
    active_profile = build_active_profile_payload(profile_id, pack_id)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    with active_profile_lock():
        previous_active = read_json(RUNTIME_DIR / "active_profile.json") if (RUNTIME_DIR / "active_profile.json").exists() else {}
        write_json(RUNTIME_DIR / "active_profile.json", active_profile)
        append_active_history(previous_active, active_profile, switch_source=switch_source, dry_run=False)
    return summary


def rollback_active_profile(switch_source: str = 'rollback') -> dict[str, Any]:
    history = read_active_history()
    if not history:
        raise SystemExit('rollback blocked: no active profile history')
    last = history[-1]
    previous_profile_id = str(last.get('previous_profile_id', '')).strip()
    previous_content_pack_id = str(last.get('previous_content_pack_id', '')).strip() or None
    if not previous_profile_id:
        raise SystemExit('rollback blocked: previous profile is empty')
    summary = switch_active_profile(previous_profile_id, previous_content_pack_id, switch_source=switch_source)
    return {
        'rolled_back_to_profile_id': previous_profile_id,
        'rolled_back_to_content_pack_id': previous_content_pack_id or '',
        'summary': summary,
    }


def build_active_profile_payload(profile_id: str, pack_id: str | None = None) -> dict[str, Any]:
    pack_id = normalize_pack_id(profile_id, pack_id)
    runtime_manifest = read_json(resolve_runtime_manifest_path(profile_id, pack_id))
    return {
        "active_mechanic_profile_id": profile_id,
        "active_content_pack_id": runtime_manifest.get("content_pack_id", pack_id or ""),
        "target_sequence_id": runtime_manifest.get("target_sequence_id", ""),
        "replacement_mode": runtime_manifest.get("replacement_mode", "full_sequence"),
        "runtime_manifest_path": to_project_relative(resolve_runtime_manifest_path(profile_id, pack_id)),
        "fallback_story_battle_loader": True,
    }


def validate_profile_ready(profile_id: str, pack_id: str | None = None) -> dict[str, Any]:
    ensure_safe_id(profile_id, "profile_id")
    if pack_id:
        ensure_safe_id(pack_id, "pack_id")
    pack_id = normalize_pack_id(profile_id, pack_id)
    mechanic_path = MECHANICS_DIR / profile_id / "mechanic_profile.json"
    recipe_path = MECHANICS_DIR / profile_id / "content_recipe.json"
    generated_dir = resolve_generated_dir(profile_id, pack_id)
    validation_path = generated_dir / "validation_report.json"
    runtime_manifest_path = generated_dir / "runtime_manifest.json"
    if not mechanic_path.exists() or not recipe_path.exists():
        raise SystemExit(f"profile does not exist: {profile_id}")
    if not validation_path.exists():
        raise SystemExit(f"validation report does not exist: {profile_id}{format_pack_suffix(pack_id)}")
    if not runtime_manifest_path.exists():
        raise SystemExit(f"runtime manifest does not exist: {profile_id}{format_pack_suffix(pack_id)}")

    mechanic_profile = read_json(mechanic_path)
    validation_report = read_json(validation_path)
    runtime_manifest = read_json(runtime_manifest_path)

    reasons: list[str] = []
    for field, expected in REQUIRED_VALIDATION_FLAGS.items():
        if validation_report.get(field) is not expected:
            reasons.append(f"{field} is not {str(expected).lower()}")
    for field in OPTIONAL_TRUE_FLAGS:
        if field in validation_report and validation_report.get(field) is not True:
            reasons.append(f"{field} is not true")

    runtime_primitives = [str(item) for item in runtime_manifest.get("runtime_primitives", mechanic_profile.get("runtime_primitives", []))]
    if runtime_primitives:
        primitive_report_path = generated_dir / "runtime_primitive_probe_report.json"
        if primitive_report_path.exists():
            primitive_report = read_json(primitive_report_path)
            if not primitive_report.get("probe_pass", False):
                reasons.append("runtime primitive probe did not pass")
        elif validation_report.get("runtime_primitive_playable") is False:
            reasons.append("runtime primitive is not playable")

    if reasons:
        raise SystemExit("active switch blocked: " + "; ".join(reasons))

    return {
        "mechanic_profile_id": profile_id,
        "content_pack_id": runtime_manifest.get("content_pack_id", pack_id or ""),
        "pack_storage_mode": "profile_pack_dir" if pack_id else "profile_root",
        "runtime_manifest_path": to_project_relative(runtime_manifest_path),
        "validation_report_path": to_project_relative(validation_path),
        "generated_dir": to_project_relative(generated_dir),
        "ready_for_runtime_export": bool(validation_report.get("ready_for_runtime_export", False)),
        "sequence_balance_pass": bool(validation_report.get("sequence_balance_pass", False)),
        "runtime_export_allowed": bool(validation_report.get("runtime_export_allowed", False)),
        "full_sequence_coverage_complete": bool(validation_report.get("full_sequence_coverage_complete", False)),
        "runtime_primitives": runtime_primitives,
        "switchable": True,
        "switch_block_reasons": [],
    }


def get_switchability(profile_id: str, pack_id: str | None = None) -> dict[str, Any]:
    try:
        pack_id = normalize_pack_id(profile_id, pack_id)
        summary = validate_profile_ready(profile_id, pack_id)
        return summary
    except SystemExit as exc:
        message = str(exc)
        prefix = "active switch blocked: "
        reasons = message[len(prefix):].split("; ") if message.startswith(prefix) else [message]
        return {
            "mechanic_profile_id": profile_id,
            "content_pack_id": pack_id or "",
            "pack_storage_mode": "profile_pack_dir" if pack_id else "profile_root",
            "switchable": False,
            "switch_block_reasons": reasons,
        }


def read_active_history() -> list[dict[str, Any]]:
    if not ACTIVE_HISTORY_PATH.exists():
        return []
    rows: list[dict[str, Any]] = []
    for line in ACTIVE_HISTORY_PATH.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line:
            continue
        rows.append(json.loads(line))
    return rows


def append_active_history(previous_active: dict[str, Any], next_active: dict[str, Any], switch_source: str, dry_run: bool) -> None:
    entry = {
        'timestamp': __import__('datetime').datetime.utcnow().isoformat() + 'Z',
        'previous_profile_id': str(previous_active.get('active_mechanic_profile_id', '')),
        'previous_content_pack_id': str(previous_active.get('active_content_pack_id', '')),
        'previous_runtime_manifest_path': str(previous_active.get('runtime_manifest_path', '')),
        'next_profile_id': str(next_active.get('active_mechanic_profile_id', '')),
        'next_content_pack_id': str(next_active.get('active_content_pack_id', '')),
        'next_runtime_manifest_path': str(next_active.get('runtime_manifest_path', '')),
        'switch_source': switch_source,
        'dry_run': bool(dry_run),
    }
    ACTIVE_HISTORY_PATH.parent.mkdir(parents=True, exist_ok=True)
    with ACTIVE_HISTORY_PATH.open('a', encoding='utf-8') as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + '\n')


def resolve_generated_dir(profile_id: str, pack_id: str | None = None) -> Path:
    pack_id = normalize_pack_id(profile_id, pack_id)
    if pack_id:
        return GENERATED_DIR / profile_id / "packs" / pack_id
    return GENERATED_DIR / profile_id


def normalize_pack_id(profile_id: str, pack_id: str | None) -> str | None:
    if not pack_id:
        return None
    root_dir = GENERATED_DIR / profile_id
    root_manifest_path = root_dir / 'runtime_manifest.json'
    if root_manifest_path.exists():
        root_manifest = read_json(root_manifest_path)
        if str(root_manifest.get('content_pack_id', '')) == str(pack_id) and not (GENERATED_DIR / profile_id / 'packs' / str(pack_id)).exists():
            return None
    return pack_id


def resolve_runtime_manifest_path(profile_id: str, pack_id: str | None = None) -> Path:
    return resolve_generated_dir(profile_id, pack_id) / "runtime_manifest.json"


def resolve_validation_report_path(profile_id: str, pack_id: str | None = None) -> Path:
    return resolve_generated_dir(profile_id, pack_id) / "validation_report.json"


def list_profile_ids() -> list[str]:
    if not MECHANICS_DIR.exists():
        return []
    return sorted(path.name for path in MECHANICS_DIR.iterdir() if path.is_dir())


def ensure_safe_id(value: str, label: str) -> None:
    if not value or not SAFE_ID_RE.fullmatch(value) or "/" in value or ".." in value or os.path.isabs(value):
        raise SystemExit(f"invalid {label}: {value}")


def format_pack_suffix(pack_id: str | None) -> str:
    return f" pack={pack_id}" if pack_id else ""


@contextmanager
def active_profile_lock():
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(str(LOCK_PATH), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise SystemExit("active profile lock exists") from exc
    try:
        os.write(fd, str(os.getpid()).encode("utf-8"))
        os.close(fd)
        yield
    finally:
        try:
            LOCK_PATH.unlink()
        except FileNotFoundError:
            pass


def to_project_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
