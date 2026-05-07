#!/usr/bin/env python3
"""v0.9-lite 简化导出入口。"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
import sys
from pathlib import Path


BEGIN_MARKER = "CONTENT_ENGINE_EXPORT_JSON_BEGIN"
END_MARKER = "CONTENT_ENGINE_EXPORT_JSON_END"
PLAN_TSV = Path("data/design/generated_battle_reward_plan.tsv")
RUNTIME_DIR = Path("data/runtime/content_engine")
BATTLE_REWARD_JSON = RUNTIME_DIR / "battle_reward.json"
CARD_POOL_JSON = RUNTIME_DIR / "card_pool.json"
MANIFEST_JSON = RUNTIME_DIR / "runtime_manifest.json"
CONFIG_JSON = RUNTIME_DIR / "runtime_loader_config.json"
ALLOWED_RUNTIME_FILES = {
    "battle_reward.json",
    "card_pool.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
ALL_DOMAINS = ["battle_reward", "card_pool"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Content Engine v0.9-lite 简化导出入口。")
    parser.add_argument("--domain", choices=["battle_reward", "all"], default="battle_reward")
    parser.add_argument("--write", action="store_true", help="执行真实导出（battle_reward 水合 + manifest 更新）。")
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


def read_tsv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def require_runtime_files() -> list[str]:
    missing: list[str] = []
    for path in [PLAN_TSV, BATTLE_REWARD_JSON, CARD_POOL_JSON, MANIFEST_JSON, CONFIG_JSON]:
        if not path.exists():
            missing.append(path.as_posix())
    return missing


def run_cmd(cmd: list[str]) -> tuple[int, str, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.returncode, proc.stdout, proc.stderr


def validate_disabled_config(config: dict) -> bool:
    return (
        config.get("content_engine_runtime_enabled") is False
        and config.get("read_only_probe_enabled") is False
        and str(config.get("integration_mode", "")) == "disabled"
        and str(config.get("fallback_mode", "")) == "existing_data_source"
    )


def main() -> int:
    args = parse_args()
    errors: list[str] = []
    notes: list[str] = []

    domains = ["battle_reward"] if args.domain == "battle_reward" else ALL_DOMAINS
    if args.domain == "all" and sorted(domains) != sorted(["battle_reward", "card_pool"]):
        errors.append("domain_all_not_allowlisted")

    missing = require_runtime_files()
    if missing:
        errors.append("missing_required_files")
        payload = {
            "ok": False,
            "write_mode": bool(args.write),
            "domain": args.domain,
            "domains_executed": domains,
            "battle_reward_record_count": 0,
            "expected_battle_reward_record_count": 0,
            "manifest_updated": False,
            "manifest_valid": False,
            "card_pool_unchanged": False,
            "runtime_loader_config_disabled": False,
            "card_pool_status": "unknown",
            "card_pool_integration_status": "unknown",
            "errors": errors + missing,
            "notes": notes,
        }
        print(BEGIN_MARKER)
        print(json.dumps(payload, ensure_ascii=False))
        print(END_MARKER)
        return 1

    card_pool_sha_before = sha256_file(CARD_POOL_JSON)
    config_sha_before = sha256_file(CONFIG_JSON)
    config_before = read_json_dict(CONFIG_JSON)

    if not args.write:
        notes.append("未提供 --write，仅执行可用性检查，不执行 hydration。")

    if args.write and "battle_reward" in domains:
        rc, out, err = run_cmd([sys.executable, "tools/content_engine/runtime_battle_reward_hydrator.py"])
        if rc != 0:
            errors.append("battle_reward_hydrator_failed")
            notes.append((out + "\n" + err).strip()[-500:])

    expected_count = len(read_tsv_rows(PLAN_TSV))
    battle_payload = read_json_dict(BATTLE_REWARD_JSON)
    manifest_payload = read_json_dict(MANIFEST_JSON)
    config_after = read_json_dict(CONFIG_JSON)
    card_pool_sha_after = sha256_file(CARD_POOL_JSON)
    config_sha_after = sha256_file(CONFIG_JSON)

    runtime_files = {p.name for p in RUNTIME_DIR.iterdir() if p.is_file()} if RUNTIME_DIR.exists() else set()
    if runtime_files != ALLOWED_RUNTIME_FILES:
        errors.append("runtime_dir_not_allowlisted")

    battle_reward_record_count = int(battle_payload.get("record_count", 0))
    if args.write and "battle_reward" in domains:
        if battle_reward_record_count != expected_count:
            errors.append("battle_reward_record_count_mismatch")
    if battle_reward_record_count <= 0:
        errors.append("battle_reward_record_count_invalid")

    manifest_entries = manifest_payload.get("files", [])
    manifest_valid = False
    manifest_updated = False
    if isinstance(manifest_entries, list):
        battle_entries = [
            x for x in manifest_entries
            if isinstance(x, dict)
            and str(x.get("runtime_domain", "")) == "battle_reward"
            and str(x.get("file_name", "")) == "battle_reward.json"
        ]
        if len(battle_entries) == 1:
            entry = battle_entries[0]
            manifest_valid = (
                str(entry.get("sha256", "")) == sha256_file(BATTLE_REWARD_JSON)
                and int(entry.get("record_count", -1)) == battle_reward_record_count
                and int(entry.get("field_count", -1)) == int(battle_payload.get("field_count", 0))
            )
            manifest_updated = True
        else:
            errors.append("manifest_battle_reward_entry_invalid")
    else:
        errors.append("manifest_files_not_array")

    if not manifest_valid:
        errors.append("manifest_not_synced")

    card_pool_unchanged = card_pool_sha_before == card_pool_sha_after
    if not card_pool_unchanged:
        errors.append("card_pool_changed_unexpectedly")

    config_unchanged = config_sha_before == config_sha_after
    if not config_unchanged:
        errors.append("runtime_loader_config_changed_unexpectedly")

    config_disabled = validate_disabled_config(config_before) and validate_disabled_config(config_after)
    if not config_disabled:
        errors.append("runtime_loader_config_not_disabled")

    card_pool_payload = read_json_dict(CARD_POOL_JSON)
    card_pool_record_count = int(card_pool_payload.get("record_count", 0))
    if card_pool_record_count == 0:
        card_pool_status = "scaffold_or_unhydrated"
        card_pool_integration_status = "out_of_scope"
    else:
        card_pool_status = "hydrated_or_non_scaffold"
        card_pool_integration_status = "out_of_scope"
        notes.append("card_pool 记录数非 0，本阶段仍保持 out_of_scope，不视为正式接入。")

    payload = {
        "ok": len(errors) == 0,
        "write_mode": bool(args.write),
        "domain": args.domain,
        "domains_executed": domains,
        "battle_reward_record_count": battle_reward_record_count,
        "expected_battle_reward_record_count": expected_count,
        "manifest_updated": manifest_updated,
        "manifest_valid": manifest_valid,
        "card_pool_unchanged": card_pool_unchanged,
        "runtime_loader_config_disabled": config_disabled,
        "card_pool_status": card_pool_status,
        "card_pool_integration_status": card_pool_integration_status,
        "errors": errors,
        "notes": notes,
    }
    print(BEGIN_MARKER)
    print(json.dumps(payload, ensure_ascii=False))
    print(END_MARKER)
    return 0 if payload["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
