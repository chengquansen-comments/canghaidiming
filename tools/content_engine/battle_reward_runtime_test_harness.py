#!/usr/bin/env python3
"""v1.0d-prep runtime_test 离线 harness。"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
from pathlib import Path

RUNTIME_REWARD_PATH = Path("data/runtime/content_engine/battle_reward.json")
RUNTIME_MANIFEST_PATH = Path("data/runtime/content_engine/runtime_manifest.json")
RUNTIME_CONFIG_PATH = Path("data/runtime/content_engine/runtime_loader_config.json")
LEGACY_REPORT_DEFAULT = Path("data/design/generated_battle_reward_legacy_flow_report.tsv")
REPORT_TSV = Path("data/design/generated_battle_reward_runtime_test_harness_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_runtime_test_harness_report.md")
FORMAL_SOURCES = {
    "data/rewards.json",
    "data/enemy_manifest.json",
    "data/story_battles.json",
}
FIELDS = [
    "record_type",
    "reward_id",
    "source_id",
    "runtime_candidate_status",
    "legacy_reference_status",
    "harness_selected_source",
    "formal_selected_source",
    "formal_runtime_effective",
    "formal_flow_touched",
    "fallback_required",
    "fallback_reason",
    "detail",
    "status",
    "severity",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="离线运行 battle_reward runtime_test harness")
    parser.add_argument("--legacy-report", default=str(LEGACY_REPORT_DEFAULT))
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def runtime_snapshot() -> dict[str, str]:
    root = Path("data/runtime/content_engine")
    result: dict[str, str] = {}
    for path in sorted(root.glob("*.json")):
        h = hashlib.sha256()
        h.update(path.read_bytes())
        result[path.name] = h.hexdigest()
    return result


def git_changed_paths() -> list[str]:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    changed: list[str] = []
    for line in out.splitlines():
        if len(line) > 3:
            path = line[3:]
            if " -> " in path:
                path = path.split(" -> ", 1)[1]
            changed.append(path)
    return sorted(set(changed))


def load_legacy_text(path: Path) -> str:
    if not path.exists():
        return ""
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        chunks: list[str] = []
        for row in reader:
            chunks.extend(v for v in row.values() if isinstance(v, str))
    return "\n".join(chunks)


def main() -> int:
    args = parse_args()
    legacy_report_path = Path(args.legacy_report)

    before_runtime = runtime_snapshot()

    runtime_payload = json.loads(RUNTIME_REWARD_PATH.read_text(encoding="utf-8"))
    _ = json.loads(RUNTIME_MANIFEST_PATH.read_text(encoding="utf-8"))
    runtime_cfg = json.loads(RUNTIME_CONFIG_PATH.read_text(encoding="utf-8"))

    records = runtime_payload.get("records", []) if isinstance(runtime_payload, dict) else []
    record_count = int(runtime_payload.get("record_count", len(records))) if isinstance(runtime_payload, dict) else len(records)

    loader_disabled = (
        isinstance(runtime_cfg, dict)
        and runtime_cfg.get("content_engine_runtime_enabled") is False
        and str(runtime_cfg.get("integration_mode", "")) == "disabled"
    )

    legacy_blob = load_legacy_text(legacy_report_path)
    rows: list[dict[str, str]] = []

    for rec in records:
        reward_id = str(rec.get("reward_plan_id", ""))
        source_id = str(rec.get("battle_slot_id", ""))
        runtime_candidate_status = "present" if reward_id else "missing_reward_id"

        matched = False
        if legacy_blob and (reward_id and reward_id in legacy_blob or source_id and source_id in legacy_blob):
            matched = True
        legacy_reference_status = "matched" if matched else "unmatched"

        fallback_required = "false" if matched else "true"
        fallback_reason = "none" if matched else "legacy_reference_unmatched"

        rows.append(
            {
                "record_type": "detail",
                "reward_id": reward_id,
                "source_id": source_id,
                "runtime_candidate_status": runtime_candidate_status,
                "legacy_reference_status": legacy_reference_status,
                "harness_selected_source": "runtime_candidate",
                "formal_selected_source": "legacy",
                "formal_runtime_effective": "false",
                "formal_flow_touched": "false",
                "fallback_required": fallback_required,
                "fallback_reason": fallback_reason,
                "detail": "离线对齐模拟：只验证候选可读与对齐，不进入正式流程。",
                "status": "PASS" if runtime_candidate_status == "present" else "FAIL",
                "severity": "blocking",
            }
        )

    after_runtime = runtime_snapshot()
    runtime_dir_modified = before_runtime != after_runtime
    changed = git_changed_paths()
    formal_replaced = any(path in FORMAL_SOURCES for path in changed)

    summary_checks = {
        "runtime_test_harness_status": "pass" if all(r["status"] == "PASS" for r in rows) and loader_disabled and record_count == 45 else "fail",
        "runtime_test_harness_mode": "true",
        "runtime_loader_config_still_disabled": "true" if loader_disabled else "false",
        "battle_reward_runtime_record_count": str(record_count),
        "harness_runtime_candidate_readable": "true" if all(r["runtime_candidate_status"] == "present" for r in rows) else "false",
        "formal_selected_source": "legacy",
        "formal_runtime_effective": "false",
        "formal_flow_touched": "false",
        "runtime_dir_modified": "true" if runtime_dir_modified else "false",
        "formal_data_source_replaced": "true" if formal_replaced else "false",
    }

    for key, actual in summary_checks.items():
        expected = {
            "runtime_test_harness_status": "pass",
            "runtime_test_harness_mode": "true",
            "runtime_loader_config_still_disabled": "true",
            "battle_reward_runtime_record_count": "45",
            "harness_runtime_candidate_readable": "true",
            "formal_selected_source": "legacy",
            "formal_runtime_effective": "false",
            "formal_flow_touched": "false",
            "runtime_dir_modified": "false",
            "formal_data_source_replaced": "false",
        }[key]
        rows.append(
            {
                "record_type": "summary",
                "reward_id": "",
                "source_id": "",
                "runtime_candidate_status": "",
                "legacy_reference_status": "",
                "harness_selected_source": "",
                "formal_selected_source": "",
                "formal_runtime_effective": "",
                "formal_flow_touched": "",
                "fallback_required": "",
                "fallback_reason": "",
                "detail": key,
                "status": "PASS" if actual == expected else "FAIL",
                "severity": "blocking",
            }
        )
        rows.append(
            {
                "record_type": "summary_value",
                "reward_id": key,
                "source_id": expected,
                "runtime_candidate_status": actual,
                "legacy_reference_status": "",
                "harness_selected_source": "",
                "formal_selected_source": "",
                "formal_runtime_effective": "",
                "formal_flow_touched": "",
                "fallback_required": "",
                "fallback_reason": "",
                "detail": f"{key}={actual}",
                "status": "PASS" if actual == expected else "FAIL",
                "severity": "blocking",
            }
        )

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    lines = [
        "# Battle Reward Runtime Test Harness 报告",
        "",
        "## 关键结论",
        "",
    ]
    for key, value in summary_checks.items():
        lines.append(f"- {key}={value}")

    lines.extend(
        [
            "",
            "## 说明",
            "",
            "- 本阶段仅做离线 harness，不修改 runtime_loader_config。",
            "- formal_selected_source 固定 legacy，formal_runtime_effective 固定 false。",
            "- 本脚本不会新增 runtime 目录文件，也不会接入 Godot 正式流程。",
            "",
        ]
    )

    Path(args.out_md).write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {args.out} and {args.out_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
