#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import switch_active_profile as switch_lib

REQUIRED_FILES = [
    "runtime_manifest.json",
    "validation_report.json",
    "formal_sequence_inventory.generated.json",
    "formal_sequence_mapping.generated.json",
    "card_pool.generated.json",
    "enemy_deck_pool.generated.json",
    "battle_slot_bindings.generated.json",
    "rewards.generated.json",
    "content_pack_summary.json",
    "sequence_balance_summary.json",
    "telemetry_probe_report.json",
    "sequence_balance_snapshot.json",
    "runtime_primitive_probe_report.json",
    "rebuild_from_snapshot_probe_report.json",
    "full_sequence_reward_probe_report.json",
    "formal_sequence_probe_report.json",
    "sequence_balance_probe_report.json",
    "runtime_primitive_probe_report.md",
    "sequence_balance_summary.md",
    "validation_report.md",
]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="snapshot generated content pack into packs/<content_pack_id>")
    parser.add_argument("profile_id")
    parser.add_argument("--pack-id", required=True)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args(argv[1:])
    snapshot = snapshot_content_pack(args.profile_id, args.pack_id, force=args.force)
    print(f"snapshotted content pack: {snapshot['snapshot_content_pack_id']}")
    return 0


def snapshot_content_pack(profile_id: str, pack_id: str, force: bool = False) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(pack_id, "pack_id")
    source_dir = switch_lib.resolve_generated_dir(profile_id)
    if not (source_dir / "runtime_manifest.json").exists():
        raise SystemExit(f"source root pack does not exist: {profile_id}")
    target_dir = switch_lib.resolve_generated_dir(profile_id, pack_id)
    if target_dir.exists():
        if not force:
            raise SystemExit(f"snapshot pack already exists: {pack_id}")
        shutil.rmtree(target_dir)
    target_dir.mkdir(parents=True, exist_ok=True)
    source_manifest = read_json(source_dir / "runtime_manifest.json")
    source_content_pack_id = str(source_manifest.get("content_pack_id", ""))
    for name in REQUIRED_FILES:
        source_path = source_dir / name
        if not source_path.exists():
            continue
        target_path = target_dir / name
        if source_path.suffix == ".json":
            payload = read_json(source_path)
            payload = rewrite_content_pack_ids(payload, source_content_pack_id, pack_id)
            if isinstance(payload, dict):
                payload.setdefault("original_content_pack_id", source_content_pack_id)
                payload.setdefault("snapshot_content_pack_id", pack_id)
            write_json(target_path, payload)
        else:
            shutil.copy2(source_path, target_path)
    summary = {
        "source_profile_id": profile_id,
        "source_content_pack_id": source_content_pack_id,
        "snapshot_content_pack_id": pack_id,
        "snapshot_dir": target_dir.relative_to(ROOT).as_posix(),
        "runtime_manifest_path": (target_dir / "runtime_manifest.json").relative_to(ROOT).as_posix(),
        "validation_report_path": (target_dir / "validation_report.json").relative_to(ROOT).as_posix(),
        "snapshot_ready": True,
    }
    write_json(target_dir / "snapshot_summary.json", summary)
    return summary


def rewrite_content_pack_ids(payload: Any, source_id: str, target_id: str) -> Any:
    if isinstance(payload, dict):
        result = {}
        for key, value in payload.items():
            if key == "content_pack_id" and (value == source_id or isinstance(value, str)):
                result[key] = target_id
            else:
                result[key] = rewrite_content_pack_ids(value, source_id, target_id)
        return result
    if isinstance(payload, list):
        return [rewrite_content_pack_ids(item, source_id, target_id) for item in payload]
    return payload


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
