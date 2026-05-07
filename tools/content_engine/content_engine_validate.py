#!/usr/bin/env python3
"""v0.9-lite 简化校验入口。"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
from pathlib import Path


BEGIN_MARKER = "CONTENT_ENGINE_VALIDATE_JSON_BEGIN"
END_MARKER = "CONTENT_ENGINE_VALIDATE_JSON_END"
RUNTIME_DIR = Path("data/runtime/content_engine")
BATTLE_REWARD_JSON = RUNTIME_DIR / "battle_reward.json"
CARD_POOL_JSON = RUNTIME_DIR / "card_pool.json"
MANIFEST_JSON = RUNTIME_DIR / "runtime_manifest.json"
CONFIG_JSON = RUNTIME_DIR / "runtime_loader_config.json"
PLAN_TSV = Path("data/design/generated_battle_reward_plan.tsv")
ALLOWED_RUNTIME_FILES = {
    "battle_reward.json",
    "card_pool.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
FORBIDDEN_HIGH_RISK = {
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "scripts/card_data.gd",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Content Engine v0.9-lite 简化校验入口。")
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json_dict(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{path} 必须是 JSON object")
    return payload


def tsv_row_count(path: Path) -> int:
    with path.open("r", encoding="utf-8", newline="") as f:
        return len(list(csv.DictReader(f, delimiter="\t")))


def config_disabled(cfg: dict) -> bool:
    return (
        cfg.get("content_engine_runtime_enabled") is False
        and cfg.get("read_only_probe_enabled") is False
        and str(cfg.get("integration_mode", "")) == "disabled"
        and str(cfg.get("fallback_mode", "")) == "existing_data_source"
    )


def count_existing_gd_references() -> int:
    targets = [
        "content_engine_runtime_loader.gd",
        "ContentEngineRuntimeLoader",
        "content_engine_runtime_gate.gd",
        "ContentEngineRuntimeGate",
        "content_engine_battle_reward_probe.gd",
        "CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_BEGIN",
    ]
    excluded = {
        "content_engine_runtime_loader.gd",
        "content_engine_runtime_gate.gd",
    }
    count = 0
    for gd in Path("scripts").glob("*.gd"):
        if gd.name in excluded:
            continue
        text = gd.read_text(encoding="utf-8")
        if any(token in text for token in targets):
            count += 1
    return count


def detect_high_risk_modified() -> list[str]:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    changed = [line[3:] for line in out.splitlines() if len(line) > 3]
    bad: list[str] = []
    for path in changed:
        if path in FORBIDDEN_HIGH_RISK:
            bad.append(path)
        if path.startswith("data/story_battles/") and path.endswith(".tsv"):
            bad.append(path)
        if path.startswith("scenes/") and path.endswith(".tscn"):
            bad.append(path)
    return sorted(set(bad))


def main() -> int:
    _ = parse_args()
    errors: list[str] = []
    notes: list[str] = []

    for path in [BATTLE_REWARD_JSON, CARD_POOL_JSON, MANIFEST_JSON, CONFIG_JSON, PLAN_TSV]:
        if not path.exists():
            errors.append(f"missing:{path.as_posix()}")
    if errors:
        payload = {
            "ok": False,
            "manifest_check_passed": False,
            "battle_reward_record_count": 0,
            "battle_reward_expected_record_count": 0,
            "runtime_files": [],
            "runtime_loader_config_disabled": False,
            "existing_gd_reference_count": -1,
            "formal_data_source_replaced": True,
            "errors": errors,
            "notes": notes,
        }
        print(BEGIN_MARKER)
        print(json.dumps(payload, ensure_ascii=False))
        print(END_MARKER)
        return 1

    battle_payload = read_json_dict(BATTLE_REWARD_JSON)
    card_pool_payload = read_json_dict(CARD_POOL_JSON)
    manifest_payload = read_json_dict(MANIFEST_JSON)
    config_payload = read_json_dict(CONFIG_JSON)

    runtime_files = sorted(p.name for p in RUNTIME_DIR.iterdir() if p.is_file()) if RUNTIME_DIR.exists() else []
    if set(runtime_files) != ALLOWED_RUNTIME_FILES:
        errors.append("runtime_dir_not_allowlisted")

    expected_count = tsv_row_count(PLAN_TSV)
    battle_count = int(battle_payload.get("record_count", 0))
    if battle_count not in {45, expected_count}:
        errors.append("battle_reward_record_count_invalid")

    manifest_ok = True
    files = manifest_payload.get("files", [])
    if not isinstance(files, list):
        manifest_ok = False
        errors.append("manifest_files_not_array")
    else:
        entry_by_name = {
            str(entry.get("file_name", "")): entry
            for entry in files
            if isinstance(entry, dict)
        }
        for file_name, path in [("battle_reward.json", BATTLE_REWARD_JSON), ("card_pool.json", CARD_POOL_JSON)]:
            entry = entry_by_name.get(file_name)
            if entry is None:
                manifest_ok = False
                errors.append(f"manifest_missing_entry:{file_name}")
                continue
            if str(entry.get("sha256", "")) != sha256_file(path):
                manifest_ok = False
                errors.append(f"manifest_sha_mismatch:{file_name}")
            payload = battle_payload if file_name == "battle_reward.json" else card_pool_payload
            if int(entry.get("record_count", -1)) != int(payload.get("record_count", -2)):
                manifest_ok = False
                errors.append(f"manifest_record_count_mismatch:{file_name}")
            if int(entry.get("field_count", -1)) != int(payload.get("field_count", -2)):
                manifest_ok = False
                errors.append(f"manifest_field_count_mismatch:{file_name}")

    cfg_disabled = config_disabled(config_payload)
    if not cfg_disabled:
        errors.append("runtime_loader_config_not_disabled")

    gd_reference_count = count_existing_gd_references()
    if gd_reference_count != 0:
        errors.append("existing_gd_references_found")

    high_risk_modified = detect_high_risk_modified()
    formal_data_source_replaced = len(high_risk_modified) > 0
    if formal_data_source_replaced:
        errors.append("high_risk_files_modified")

    card_pool_count = int(card_pool_payload.get("record_count", 0))
    if card_pool_count == 0:
        notes.append("card_pool_status=scaffold_or_unhydrated")
        notes.append("card_pool_integration_status=out_of_scope")

    payload = {
        "ok": len(errors) == 0,
        "manifest_check_passed": manifest_ok,
        "battle_reward_record_count": battle_count,
        "battle_reward_expected_record_count": expected_count,
        "runtime_files": runtime_files,
        "runtime_loader_config_disabled": cfg_disabled,
        "existing_gd_reference_count": gd_reference_count,
        "formal_data_source_replaced": formal_data_source_replaced,
        "high_risk_modified_files": high_risk_modified,
        "errors": errors,
        "notes": notes,
    }

    print(BEGIN_MARKER)
    print(json.dumps(payload, ensure_ascii=False))
    print(END_MARKER)
    return 0 if payload["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
