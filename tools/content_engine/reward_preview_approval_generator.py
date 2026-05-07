#!/usr/bin/env python3
"""v1.2a reward-only preview approval 生成器。"""

from __future__ import annotations

import csv
from pathlib import Path

DESIGN_DIR = Path("data/design")
MANUAL_OVERLAY = DESIGN_DIR / "manual_reward_preview_approval_overlay.tsv"
VALIDATOR_SUMMARY = DESIGN_DIR / "generated_validator_summary.tsv"
MANIFEST = DESIGN_DIR / "generated_content_package_manifest.tsv"
APPROVAL = DESIGN_DIR / "generated_content_package_approval.tsv"
DRY_RUN = DESIGN_DIR / "generated_runtime_export_dry_run.tsv"
REWARD_PLAN = DESIGN_DIR / "generated_battle_reward_plan.tsv"
OUT_TSV = DESIGN_DIR / "generated_reward_preview_approval.tsv"
OUT_MD = DESIGN_DIR / "generated_reward_preview_approval.md"

FIELDS = [
    "approval_id",
    "artifact_id",
    "artifact_path",
    "validator_status",
    "validator_warning_count",
    "validator_error_count",
    "approval_scope",
    "approval_status",
    "approved_for_preview",
    "approved_for_runtime",
    "risk_level",
    "preview_allowed",
    "runtime_allowed",
    "blockers",
    "notes",
]


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def parse_bool(value: str) -> bool:
    return str(value).strip().lower() in {"true", "1", "yes"}


def main() -> int:
    for p in [MANUAL_OVERLAY, VALIDATOR_SUMMARY, MANIFEST, APPROVAL, DRY_RUN, REWARD_PLAN]:
        if not p.exists():
            raise FileNotFoundError(f"missing required input: {p.as_posix()}")

    overlay_rows = read_tsv(MANUAL_OVERLAY)
    if len(overlay_rows) != 1:
        raise ValueError("manual overlay must contain exactly one row")
    row = overlay_rows[0]

    if row.get("artifact_id") != "generated_battle_reward_plan":
        raise ValueError("overlay artifact_id must be generated_battle_reward_plan")

    manifest_rows = read_tsv(MANIFEST)
    manifest_by_id = {r.get("artifact_id", ""): r for r in manifest_rows}
    artifact_path = manifest_by_id.get("generated_battle_reward_plan", {}).get("artifact_path", "data/design/generated_battle_reward_plan.tsv")

    validator_rows = read_tsv(VALIDATOR_SUMMARY)
    validator_status = "MISSING"
    warning_count = "999"
    error_count = "999"
    for vr in validator_rows:
        targets = [x.strip() for x in str(vr.get("target_artifact_id", "")).split(",") if x.strip()]
        if "generated_battle_reward_plan" in targets:
            validator_status = vr.get("status", "MISSING")
            warning_count = vr.get("warning_count", "999")
            error_count = vr.get("error_count", "999")
            break

    approved_for_preview = parse_bool(row.get("approved_for_preview", "false"))
    approved_for_runtime = parse_bool(row.get("approved_for_runtime", "false"))

    blockers: list[str] = []
    if validator_status != "PASS":
        blockers.append("validator_not_pass")
    if warning_count != "0":
        blockers.append("validator_warning_nonzero")
    if error_count != "0":
        blockers.append("validator_error_nonzero")
    if row.get("approval_scope") != "reward_preview":
        blockers.append("approval_scope_invalid")
    if row.get("approval_status") != "approved":
        blockers.append("approval_status_not_approved")
    if not approved_for_preview:
        blockers.append("approved_for_preview_false")
    if approved_for_runtime:
        blockers.append("approved_for_runtime_must_false")

    preview_allowed = len(blockers) == 0
    runtime_allowed = False

    out_row = {
        "approval_id": row.get("approval_id", ""),
        "artifact_id": "generated_battle_reward_plan",
        "artifact_path": artifact_path,
        "validator_status": validator_status,
        "validator_warning_count": warning_count,
        "validator_error_count": error_count,
        "approval_scope": row.get("approval_scope", ""),
        "approval_status": row.get("approval_status", ""),
        "approved_for_preview": "true" if approved_for_preview else "false",
        "approved_for_runtime": "true" if approved_for_runtime else "false",
        "risk_level": row.get("risk_level", ""),
        "preview_allowed": "true" if preview_allowed else "false",
        "runtime_allowed": "false",
        "blockers": "none" if not blockers else ",".join(blockers),
        "notes": "reward_preview_only;runtime_not_allowed;runtime_files_written=0",
    }

    with OUT_TSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerow(out_row)

    md = [
        "# Reward Preview Approval",
        "",
        "## 概要",
        "",
        "- 阶段：v1.2a reward-only preview approval overlay",
        "- 仅处理：generated_battle_reward_plan",
        f"- preview_allowed：{out_row['preview_allowed']}",
        f"- runtime_allowed：{out_row['runtime_allowed']}",
        "- runtime 文件写入：0",
        "",
        "## 审批结论",
        "",
        f"- approval_id：{out_row['approval_id']}",
        f"- approval_scope：{out_row['approval_scope']}",
        f"- approval_status：{out_row['approval_status']}",
        f"- approved_for_preview：{out_row['approved_for_preview']}",
        f"- approved_for_runtime：{out_row['approved_for_runtime']}",
        f"- blockers：{out_row['blockers']}",
        "",
        "## 安全边界",
        "",
        "- 本审批仅用于 reward preview 候选，不属于 runtime approval。",
        "- 不写 runtime，不接 Godot，不改变玩家奖励与战斗流程。",
        "",
    ]
    OUT_MD.write_text("\n".join(md), encoding="utf-8")

    print(f"Wrote {OUT_TSV.as_posix()} and {OUT_MD.as_posix()}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
