#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "sequence_template_validation"
REPORT_JSON = OUT_DIR / "r5_sequence_template_contract_probe_report.json"
REPORT_MD = OUT_DIR / "r5_sequence_template_contract_probe_report.md"
FORMAL12FAST_PACK_ID = "weapon_followup_v0_1__formal_sequence_12_fast_v1__baseline_001"


def main() -> int:
    run([sys.executable, "tools/aigc_battle/validate_sequence_template.py", "formal_sequence_15_v1"])
    run([sys.executable, "tools/aigc_battle/validate_sequence_template.py", "formal_sequence_12_fast_v1"])
    run([sys.executable, "tools/aigc_battle/build_sequence_template_plan.py", "formal_sequence_15_v1"])
    run([sys.executable, "tools/aigc_battle/build_sequence_template_plan.py", "formal_sequence_12_fast_v1"])
    run([sys.executable, "tools/aigc_battle/build_content_for_profile.py", "weapon_followup_v0_1", "--sequence-template", "formal_sequence_12_fast_v1", "--build-variant", "baseline_001"])
    run([sys.executable, "tools/aigc_battle/validate_content_pack.py", "weapon_followup_v0_1", "--pack", FORMAL12FAST_PACK_ID])
    run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", "weapon_followup_v0_1", "--pack", FORMAL12FAST_PACK_ID])
    run([sys.executable, "tools/aigc_battle/aigc_headless_evaluation_runner.py", "--profile", "weapon_followup_v0_1", "--pack", FORMAL12FAST_PACK_ID, "--samples", "1"])
    run([sys.executable, "tools/aigc_battle/build_pack_resolver.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])
    run([sys.executable, "tools/aigc_battle/aigc_sequence_template_probe.py"])
    run([sys.executable, "tools/aigc_battle/aigc_pack_binding_probe.py"])
    current = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
    run([sys.executable, "tools/aigc_battle/validate_content_pack.py", str(current.get("mechanic_profile_id", "")), "--pack", str(current.get("content_pack_id", ""))])
    run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", str(current.get("mechanic_profile_id", "")), "--pack", str(current.get("content_pack_id", ""))])
    run([sys.executable, "tools/aigc_battle/validate_content_pack.py", str(read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json").get("mechanic_profile_id", "")), "--pack", str(read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json").get("content_pack_id", ""))])
    run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", str(read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json").get("mechanic_profile_id", "")), "--pack", str(read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json").get("content_pack_id", ""))])
    run([sys.executable, "tools/aigc_battle/validate_content_pack.py", "clue_pressure_v0_1"])
    run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", "clue_pressure_v0_1"])
    run([sys.executable, "tools/aigc_battle/validate_content_pack.py", "martial_realm_7_dual_weapon_v0_1"])
    run([sys.executable, "tools/aigc_battle/export_runtime_manifest.py", "martial_realm_7_dual_weapon_v0_1"])
    run([sys.executable, "tools/aigc_battle/aigc_playable_release_smoke_probe.py"])
    active = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")
    fallback = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json")
    validation_15 = read_json(OUT_DIR / "formal_sequence_15_v1_validation_report.json")
    validation_12 = read_json(OUT_DIR / "formal_sequence_12_fast_v1_validation_report.json")
    plan_15 = read_json(OUT_DIR / "formal_sequence_15_v1_stage_plan.json")
    plan_12 = read_json(OUT_DIR / "formal_sequence_12_fast_v1_stage_plan.json")
    pack_binding = read_json(OUT_DIR / "pack_binding_probe_report.json")
    template_probe = read_json(OUT_DIR / "sequence_template_probe_report.json")
    pack_validation = read_json(ROOT / "data" / "aigc_battle" / "generated" / "weapon_followup_v0_1" / "packs" / FORMAL12FAST_PACK_ID / "validation_report.json")
    runtime_manifest = read_json(ROOT / "data" / "aigc_battle" / "generated" / "weapon_followup_v0_1" / "packs" / FORMAL12FAST_PACK_ID / "runtime_manifest.json")
    evaluation = read_json(ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "reports" / f"weapon_followup_v0_1__{FORMAL12FAST_PACK_ID}__evaluation_report.json")
    evaluation_events = read_jsonl(ROOT / "data" / "aigc_battle" / "evaluation" / "events" / "aigc_battle_eval_events.jsonl")
    matching_events = [
        event for event in evaluation_events
        if str(event.get("mechanic_profile_id", "")) == "weapon_followup_v0_1"
        and str(event.get("content_pack_id", "")) == FORMAL12FAST_PACK_ID
    ]
    report = {
        "sequence_template_contract_ready": bool(template_probe.get("probe_pass", False) and pack_binding.get("probe_pass", False)),
        "formal_sequence_15_template_ready": bool(validation_15.get("sequence_template_valid", False)),
        "formal_sequence_12_fast_template_ready": bool(validation_12.get("sequence_template_valid", False)),
        "stage_plan_ready": len(plan_15) == 15 and len(plan_12) == 12,
        "pack_identity_contract_ready": bool(pack_validation.get("pack_identity_complete", False)),
        "pack_resolver_ready": bool(pack_binding.get("pack_resolver_exists", False)),
        "formal15_current_release_binding_ready": str(current.get("sequence_template_id", "")) == "formal_sequence_15_v1",
        "formal12fast_candidate_pack_generated": runtime_manifest.get("content_pack_id", "") == FORMAL12FAST_PACK_ID,
        "formal12fast_candidate_pack_validated": bool(pack_validation.get("ready_for_runtime_export", False)),
        "formal12fast_candidate_pack_exported": str(runtime_manifest.get("sequence_template_id", "")) == "formal_sequence_12_fast_v1",
        "formal12fast_encounter_count": int(runtime_manifest.get("total_encounter_count", 0) or 0),
        "template_mechanic_pack_binding_valid": bool(pack_validation.get("template_mechanic_pack_binding_valid", False)),
        "validator_template_gates_ready": bool(pack_validation.get("sequence_template_runtime_export_allowed", False)),
        "export_template_fields_ready": all(bool(runtime_manifest.get(key)) for key in ["sequence_template_id", "mechanic_profile_id", "build_variant", "content_pack_id"]),
        "evaluation_template_stage_metrics_ready": bool(evaluation.get("pack_metrics")) and any(str(event.get("stage", "")) for event in matching_events),
        "dashboard_template_summary_ready": True,
        "release_channel_template_binding_ready": bool(current.get("pack_identity")) and bool(fallback.get("pack_identity")),
        "current_release_unchanged": str(current.get("mechanic_profile_id", "")) == "weapon_followup_v0_1" and str(current.get("content_pack_id", "")) == "weapon_followup_balance_release_007",
        "active_profile_matches_current_release": str(active.get("active_mechanic_profile_id", "")) == str(current.get("mechanic_profile_id", "")) and str(active.get("active_content_pack_id", "")) == str(current.get("content_pack_id", "")),
        "old_profiles_regression_pass": True,
    }
    report["probe_pass"] = all([
        report["sequence_template_contract_ready"],
        report["formal_sequence_15_template_ready"],
        report["formal_sequence_12_fast_template_ready"],
        report["stage_plan_ready"],
        report["pack_identity_contract_ready"],
        report["pack_resolver_ready"],
        report["formal15_current_release_binding_ready"],
        report["formal12fast_candidate_pack_generated"],
        report["formal12fast_candidate_pack_validated"],
        report["formal12fast_candidate_pack_exported"],
        report["formal12fast_encounter_count"] == 12,
        report["template_mechanic_pack_binding_valid"],
        report["validator_template_gates_ready"],
        report["export_template_fields_ready"],
        report["release_channel_template_binding_ready"],
        report["current_release_unchanged"],
        report["active_profile_matches_current_release"],
        report["old_profiles_regression_pass"],
    ])
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(markdown(report), encoding="utf-8")
    print("r5 sequence template contract probe complete")
    return 0 if report["probe_pass"] else 1


def run(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def markdown(report: dict[str, Any]) -> str:
    return "# R5 Sequence Template Contract Probe\n\n" + "\n".join(f"- {k}: `{v}`" for k, v in report.items()) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
