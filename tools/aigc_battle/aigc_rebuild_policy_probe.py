#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"
TOOLS_DIR = ROOT / "tools" / "aigc_battle"
PROFILE_A = "posture_basic_v0_1"
PROFILE_B = "posture_tuned_v0_1b"


def main() -> int:
    report_a = run_diff(PROFILE_A, PROFILE_B)
    with tempfile.TemporaryDirectory(prefix="aigc_policy_probe_") as temp_dir:
        tmp_root = Path(temp_dir)
        unsupported_dir = build_temp_profile(
            tmp_root / "unsupported_design_effect_profile",
            PROFILE_A,
            inject_unsupported_design_effect,
        )
        regen_dir = build_temp_profile(
            tmp_root / "full_regen_profile",
            PROFILE_A,
            inject_full_regeneration_change,
        )
        report_b = run_diff(PROFILE_A, unsupported_dir.as_posix())
        report_c = run_diff(PROFILE_A, regen_dir.as_posix())

    restored = run_diff(PROFILE_A, PROFILE_B)
    profile_a_validation = read_json(GENERATED_DIR / PROFILE_A / "validation_report.json")
    profile_b_validation = read_json(GENERATED_DIR / PROFILE_B / "validation_report.json")

    value_rebalance_detected = report_a.get("change_type") == "value_rebalance"
    full_sequence_regeneration_detected = report_c.get("change_type") == "full_sequence_regeneration" and bool(report_c.get("full_sequence_rebuild_required", False))
    unsupported_runtime_effect_blocked = report_b.get("change_type") == "not_runtime_playable" and bool(report_b.get("not_runtime_playable", False))
    recommended_action_present = all(str(report.get("recommended_action", "")).strip() for report in [report_a, report_b, report_c])
    rebuilt_pack_full_sequence_valid = bool(profile_a_validation.get("ready_for_runtime_export", False)) and bool(profile_b_validation.get("ready_for_runtime_export", False))

    report = {
        "profile_diff_ready": bool(restored.get("from_profile_id")) and bool(restored.get("to_profile_id")),
        "regeneration_policy_ready": True,
        "value_rebalance_detected": value_rebalance_detected,
        "full_sequence_regeneration_detected": full_sequence_regeneration_detected,
        "unsupported_runtime_effect_blocked": unsupported_runtime_effect_blocked,
        "recommended_action_present": recommended_action_present,
        "not_runtime_playable_blocked": unsupported_runtime_effect_blocked and report_b.get("recommended_action") == "block_runtime_export_until_runtime_support_exists",
        "rebuilt_pack_full_sequence_valid": rebuilt_pack_full_sequence_valid,
        "policy_probe_pass": False,
    }
    report["policy_probe_pass"] = all(
        [
            report["profile_diff_ready"],
            report["regeneration_policy_ready"],
            report["value_rebalance_detected"],
            report["full_sequence_regeneration_detected"],
            report["unsupported_runtime_effect_blocked"],
            report["recommended_action_present"],
            report["not_runtime_playable_blocked"],
            report["rebuilt_pack_full_sequence_valid"],
        ]
    )
    write_json(GENERATED_DIR / "rebuild_policy_probe_report.json", report)
    write_markdown(GENERATED_DIR / "rebuild_policy_probe_report.md", report)
    print("rebuild policy probe complete")
    return 0 if report["policy_probe_pass"] else 1


def build_temp_profile(target_dir: Path, source_profile_id: str, mutator) -> Path:
    source_dir = ROOT / "data" / "aigc_battle" / "mechanics" / source_profile_id
    target_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_dir / "mechanic_profile.json", target_dir / "mechanic_profile.json")
    shutil.copy2(source_dir / "content_recipe.json", target_dir / "content_recipe.json")
    mutator(target_dir)
    return target_dir


def inject_unsupported_design_effect(target_dir: Path) -> None:
    profile = read_json(target_dir / "mechanic_profile.json")
    profile["mechanic_profile_id"] = "tmp_unsupported_design_effect_probe"
    design_effects = list(profile.get("allowed_design_effects", []))
    design_effects.append("combo_trigger_probe_only")
    profile["allowed_design_effects"] = design_effects
    write_json(target_dir / "mechanic_profile.json", profile)


def inject_full_regeneration_change(target_dir: Path) -> None:
    profile = read_json(target_dir / "mechanic_profile.json")
    recipe = read_json(target_dir / "content_recipe.json")
    profile["mechanic_profile_id"] = "tmp_full_regen_probe"
    recipe["mechanic_profile_id"] = "tmp_full_regen_probe"
    recipe["content_pack_id"] = "tmp_full_regen_probe_pack"
    recipe["target_sequence_id"] = "formal_sequence_probe_v2"
    recipe["replacement_mode"] = "sequence_override_probe"
    write_json(target_dir / "mechanic_profile.json", profile)
    write_json(target_dir / "content_recipe.json", recipe)


def run_diff(from_profile: str, to_profile: str) -> dict[str, Any]:
    subprocess.run(
        [sys.executable, str(TOOLS_DIR / "diff_mechanic_profiles.py"), from_profile, to_profile],
        check=True,
        cwd=ROOT,
    )
    return read_json(GENERATED_DIR / "profile_diff_report.json")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# AIGC Battle v5 Rebuild Policy Probe",
        "",
        f"- profile_diff_ready: {str(report['profile_diff_ready']).lower()}",
        f"- regeneration_policy_ready: {str(report['regeneration_policy_ready']).lower()}",
        f"- value_rebalance_detected: {str(report['value_rebalance_detected']).lower()}",
        f"- full_sequence_regeneration_detected: {str(report['full_sequence_regeneration_detected']).lower()}",
        f"- unsupported_runtime_effect_blocked: {str(report['unsupported_runtime_effect_blocked']).lower()}",
        f"- recommended_action_present: {str(report['recommended_action_present']).lower()}",
        f"- not_runtime_playable_blocked: {str(report['not_runtime_playable_blocked']).lower()}",
        f"- rebuilt_pack_full_sequence_valid: {str(report['rebuilt_pack_full_sequence_valid']).lower()}",
        f"- policy_probe_pass: {str(report['policy_probe_pass']).lower()}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
