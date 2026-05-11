#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated"
RUNTIME_DIR = ROOT / "data" / "aigc_battle" / "runtime"
TOOLS_DIR = ROOT / "tools" / "aigc_battle"
PROFILE_A = "posture_basic_v0_1"
PROFILE_B = "posture_tuned_v0_1b"


def main() -> int:
    profile_a = load_profile_state(PROFILE_A)
    profile_b = load_profile_state(PROFILE_B)
    run_switch(PROFILE_A)
    active_after_a = read_json(RUNTIME_DIR / "active_profile.json")
    run_switch(PROFILE_B)
    active_after_b = read_json(RUNTIME_DIR / "active_profile.json")
    run_switch(PROFILE_A)
    final_active = read_json(RUNTIME_DIR / "active_profile.json")

    profile_a_ready = evaluate_profile_ready(profile_a)
    profile_b_ready = evaluate_profile_ready(profile_b)
    runtime_manifest_paths_distinct = profile_a["active_profile"]["runtime_manifest_path"] != profile_b["active_profile"]["runtime_manifest_path"]
    content_pack_isolated = profile_a["manifest"]["content_pack_id"] != profile_b["manifest"]["content_pack_id"]
    profile_outputs_isolated = profile_a["generated_dir"] != profile_b["generated_dir"]
    profile_data_diff_detected = detect_profile_diff(profile_a, profile_b)
    fallback_after_switch = max(
        int(profile_a["formal_probe"].get("fallback_loadout_count", 999)),
        int(profile_b["formal_probe"].get("fallback_loadout_count", 999)),
    )
    report = {
        "profile_a_id": PROFILE_A,
        "profile_b_id": PROFILE_B,
        "profile_a_ready": profile_a_ready,
        "profile_b_ready": profile_b_ready,
        "profile_a_full_sequence_coverage_complete": bool(profile_a["validation"].get("full_sequence_coverage_complete", False)),
        "profile_b_full_sequence_coverage_complete": bool(profile_b["validation"].get("full_sequence_coverage_complete", False)),
        "profile_a_sequence_balance_pass": bool(profile_a["validation"].get("sequence_balance_pass", False)),
        "profile_b_sequence_balance_pass": bool(profile_b["validation"].get("sequence_balance_pass", False)),
        "profile_a_reward_closure_ready": bool(profile_a["reward_probe"].get("full_sequence_loop_closed", False)),
        "profile_b_reward_closure_ready": bool(profile_b["reward_probe"].get("full_sequence_loop_closed", False)),
        "active_profile_switch_ready": str(active_after_a.get("active_mechanic_profile_id", "")) == PROFILE_A and str(active_after_b.get("active_mechanic_profile_id", "")) == PROFILE_B,
        "formal_route_profile_agnostic": fallback_after_switch == 0,
        "content_pack_isolated": content_pack_isolated,
        "runtime_manifest_paths_distinct": runtime_manifest_paths_distinct,
        "profile_outputs_isolated": profile_outputs_isolated,
        "profile_data_diff_detected": profile_data_diff_detected,
        "fallback_loadout_count_after_switch": fallback_after_switch,
        "full_sequence_playable_after_switch": profile_a_ready and profile_b_ready and fallback_after_switch == 0,
        "final_active_profile_id": str(final_active.get("active_mechanic_profile_id", "")),
    }
    write_json(GENERATED_DIR / "profile_switch_probe_report.json", report)
    write_markdown(GENERATED_DIR / "profile_switch_probe_report.md", report)
    print("profile switch probe complete")
    ok = (
        report["profile_a_ready"]
        and report["profile_b_ready"]
        and report["active_profile_switch_ready"]
        and report["formal_route_profile_agnostic"]
        and report["content_pack_isolated"]
        and report["runtime_manifest_paths_distinct"]
        and report["profile_outputs_isolated"]
        and report["profile_data_diff_detected"]
        and report["fallback_loadout_count_after_switch"] == 0
        and report["full_sequence_playable_after_switch"]
    )
    return 0 if ok else 1


def load_profile_state(profile_id: str) -> dict[str, Any]:
    generated_dir = GENERATED_DIR / profile_id
    return {
        "generated_dir": generated_dir.as_posix(),
        "validation": read_json(generated_dir / "validation_report.json"),
        "manifest": read_json(generated_dir / "runtime_manifest.json"),
        "balance": read_json(generated_dir / "sequence_balance_summary.json"),
        "formal_probe": read_json(generated_dir / "formal_sequence_probe_report.json"),
        "reward_probe": read_json(generated_dir / "full_sequence_reward_probe_report.json"),
        "balance_probe": read_json(generated_dir / "sequence_balance_probe_report.json"),
        "active_profile": {
            "runtime_manifest_path": f"data/aigc_battle/generated/{profile_id}/runtime_manifest.json"
        },
    }


def evaluate_profile_ready(profile_state: dict[str, Any]) -> bool:
    validation = profile_state["validation"]
    formal_probe = profile_state["formal_probe"]
    reward_probe = profile_state["reward_probe"]
    balance_probe = profile_state["balance_probe"]
    return (
        bool(validation.get("full_sequence_coverage_complete", False))
        and bool(validation.get("sequence_balance_pass", False))
        and bool(validation.get("ready_for_runtime_export", False))
        and bool(formal_probe.get("all_formal_battles_use_generated_loadout", False))
        and int(formal_probe.get("fallback_loadout_count", 999)) == 0
        and bool(reward_probe.get("full_sequence_loop_closed", False))
        and bool(balance_probe.get("sequence_balance_pass", False))
    )


def detect_profile_diff(profile_a: dict[str, Any], profile_b: dict[str, Any]) -> bool:
    manifest_a = profile_a["manifest"]
    manifest_b = profile_b["manifest"]
    balance_a = profile_a["balance"]
    balance_b = profile_b["balance"]
    reward_tiers_a = sorted({str(item.get("reward_tier", "")) for item in manifest_a.get("rewards", [])})
    reward_tiers_b = sorted({str(item.get("reward_tier", "")) for item in manifest_b.get("rewards", [])})
    return any(
        [
            len(manifest_a.get("cards", [])) != len(manifest_b.get("cards", [])),
            len(manifest_a.get("enemy_decks", [])) != len(manifest_b.get("enemy_decks", [])),
            float(balance_a.get("early_avg_power", 0)) != float(balance_b.get("early_avg_power", 0)),
            float(balance_a.get("mid_avg_power", 0)) != float(balance_b.get("mid_avg_power", 0)),
            float(balance_a.get("late_avg_power", 0)) != float(balance_b.get("late_avg_power", 0)),
            float(balance_a.get("boss_avg_power", 0)) != float(balance_b.get("boss_avg_power", 0)),
            reward_tiers_a != reward_tiers_b,
        ]
    )


def run_switch(profile_id: str) -> None:
    subprocess.run([sys.executable, str(TOOLS_DIR / "switch_active_profile.py"), profile_id], check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# AIGC Battle v4 Profile Switch Probe",
        "",
        f"- profile_a_ready: {str(report['profile_a_ready']).lower()}",
        f"- profile_b_ready: {str(report['profile_b_ready']).lower()}",
        f"- active_profile_switch_ready: {str(report['active_profile_switch_ready']).lower()}",
        f"- formal_route_profile_agnostic: {str(report['formal_route_profile_agnostic']).lower()}",
        f"- content_pack_isolated: {str(report['content_pack_isolated']).lower()}",
        f"- runtime_manifest_paths_distinct: {str(report['runtime_manifest_paths_distinct']).lower()}",
        f"- profile_outputs_isolated: {str(report['profile_outputs_isolated']).lower()}",
        f"- profile_data_diff_detected: {str(report['profile_data_diff_detected']).lower()}",
        f"- fallback_loadout_count_after_switch: {report['fallback_loadout_count_after_switch']}",
        f"- full_sequence_playable_after_switch: {str(report['full_sequence_playable_after_switch']).lower()}",
        f"- final_active_profile_id: {report['final_active_profile_id']}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
