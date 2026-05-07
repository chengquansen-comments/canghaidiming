#!/usr/bin/env python3
"""v0.9-lite 简化 Godot 只读探测入口。"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path


BEGIN_MARKER = "CONTENT_ENGINE_GODOT_PROBE_JSON_BEGIN"
END_MARKER = "CONTENT_ENGINE_GODOT_PROBE_JSON_END"
PROBE_BEGIN = "CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_BEGIN"
PROBE_END = "CONTENT_ENGINE_BATTLE_REWARD_PROBE_JSON_END"
PROBE_SCRIPT = "tools/content_engine/content_engine_battle_reward_probe.gd"
COMPARE_SCRIPT = "tools/content_engine/runtime_battle_reward_godot_compare.py"
COMPARE_TSV = Path("data/design/generated_runtime_battle_reward_godot_compare_report.tsv")
CONFIG_JSON = Path("data/runtime/content_engine/runtime_loader_config.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Content Engine v0.9-lite 简化 Godot probe 入口。")
    parser.add_argument("--godot-cmd", default="godot")
    return parser.parse_args()


def parse_marker_payload(text: str, begin: str, end: str) -> dict:
    start = text.find(begin)
    stop = text.find(end)
    if start < 0 or stop < 0 or stop <= start:
        raise ValueError("marker payload missing")
    content = text[start + len(begin):stop].strip()
    payload = json.loads(content)
    if not isinstance(payload, dict):
        raise ValueError("payload must be JSON object")
    return payload


def read_compare_row(path: Path) -> dict[str, str]:
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        rows = list(reader)
    if len(rows) != 1:
        raise ValueError(f"{path} row count must be 1, got {len(rows)}")
    return rows[0]


def read_config(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("runtime_loader_config.json must be object")
    return payload


def bool_text(flag: object) -> str:
    return "true" if bool(flag) else "false"


def main() -> int:
    args = parse_args()
    errors: list[str] = []

    godot_cmd = [args.godot_cmd, "--headless", "--path", ".", "--script", PROBE_SCRIPT]
    godot_proc = subprocess.run(godot_cmd, capture_output=True, text=True)
    probe_payload: dict
    try:
        probe_payload = parse_marker_payload(godot_proc.stdout, PROBE_BEGIN, PROBE_END)
    except (ValueError, json.JSONDecodeError) as exc:
        probe_payload = {
            "ok": False,
            "manifest_loaded": False,
            "manifest_valid": False,
            "runtime_loaded": False,
            "runtime_record_count": 0,
            "error_count": 1,
            "integration_status": "godot_compare_only",
            "formal_data_source_replaced": False,
        }
        errors.append(f"probe_payload_parse_failed:{exc}")

    compare_proc = subprocess.run([sys.executable, COMPARE_SCRIPT], capture_output=True, text=True)
    if compare_proc.returncode != 0:
        errors.append("runtime_battle_reward_godot_compare_failed")

    compare_row = read_compare_row(COMPARE_TSV)
    config = read_config(CONFIG_JSON)

    gate_config_enabled = bool(config.get("content_engine_runtime_enabled", False))
    gate_integration_mode = str(config.get("integration_mode", ""))

    loader_ok = (
        godot_proc.returncode == 0
        and bool(probe_payload.get("manifest_loaded", False))
        and bool(probe_payload.get("runtime_loaded", False))
        and int(probe_payload.get("error_count", 1)) == 0
    )

    compare_ok = (
        compare_row.get("godot_probe_exit_code", "") == "0"
        and compare_row.get("godot_probe_ok", "") == "true"
        and compare_row.get("godot_runtime_record_count", "") == "45"
        and compare_row.get("python_runtime_record_count", "") == "45"
        and compare_row.get("legacy_record_count", "") == "45"
        and compare_row.get("manifest_loaded", "") == "true"
        and compare_row.get("runtime_loaded", "") == "true"
        and compare_row.get("formal_data_source_replaced", "") == "false"
        and compare_row.get("gate_config_enabled", "") == "false"
        and compare_row.get("gate_integration_mode", "") == "disabled"
    )

    integration_status = str(compare_row.get("integration_status", ""))
    if integration_status not in {"not_integrated", "compare_only", "godot_compare_only"}:
        errors.append("integration_status_invalid")

    if gate_config_enabled or gate_integration_mode != "disabled":
        errors.append("gate_not_disabled")

    ok = loader_ok and compare_ok and len(errors) == 0
    payload = {
        "ok": ok,
        "godot_exit_code": godot_proc.returncode,
        "manifest_loaded": bool(probe_payload.get("manifest_loaded", False)),
        "runtime_loaded": bool(probe_payload.get("runtime_loaded", False)),
        "error_count": int(probe_payload.get("error_count", 0)),
        "battle_reward_godot_record_count": int(compare_row.get("godot_runtime_record_count", "0")),
        "battle_reward_python_record_count": int(compare_row.get("python_runtime_record_count", "0")),
        "battle_reward_legacy_record_count": int(compare_row.get("legacy_record_count", "0")),
        "integration_status": integration_status,
        "formal_data_source_replaced": compare_row.get("formal_data_source_replaced", "false") == "true",
        "gate_config_enabled": gate_config_enabled,
        "gate_integration_mode": gate_integration_mode,
        "errors": errors,
    }

    print(BEGIN_MARKER)
    print(json.dumps(payload, ensure_ascii=False))
    print(END_MARKER)
    return 0 if payload["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
