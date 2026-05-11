#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import switch_active_profile as switch_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "balance_release"
REPORT_JSON = OUT_DIR / "balance_release_smoke_report.json"
REPORT_MD = OUT_DIR / "balance_release_smoke_report.md"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="smoke probe for balanced current release")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--pack", required=True)
    args = parser.parse_args(argv[1:])
    report = smoke_probe(args.profile, args.pack)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report.get("smoke_pass", False) else 1


def smoke_probe(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    current = release_lib.read_release_channel("current", required=True)
    active = release_lib.read_active_profile()
    if str(current.get("mechanic_profile_id", "")) != profile_id or str(current.get("content_pack_id", "")) != content_pack_id:
        raise SystemExit("current release does not point to balanced pack")
    if str(active.get("active_mechanic_profile_id", "")) != profile_id or str(active.get("active_content_pack_id", "")) != content_pack_id:
        raise SystemExit("active profile does not point to balanced pack")

    run_serial([sys.executable, "tools/aigc_battle/aigc_formal_entry_release_probe.py"])
    run_serial([sys.executable, "tools/aigc_battle/aigc_full_sequence_reward_probe.py"])
    run_serial([sys.executable, "tools/aigc_battle/aigc_sequence_balance_probe.py"])
    run_serial([sys.executable, "tools/aigc_battle/aigc_weapon_followup_probe.py"])

    formal = read_json(ROOT / "data" / "aigc_battle" / "generated" / "release_smoke" / "formal_entry_release_probe_report.json")
    reward = read_json((switch_lib.resolve_generated_dir(profile_id, content_pack_id)) / "full_sequence_reward_probe_report.json")
    balance = read_json(ROOT / "data" / "aigc_battle" / "generated" / profile_id / "sequence_balance_probe_report.json")
    followup = read_json(ROOT / "data" / "aigc_battle" / "generated" / profile_id / "weapon_followup_probe_report.json")
    channels = release_lib.show_channels()
    previous_ready = previous_current_ready(profile_id, content_pack_id)

    report = {
        "current_release_points_to_balanced_pack": True,
        "active_profile_points_to_balanced_pack": True,
        "formal_entry_uses_balanced_release": bool(formal.get("formal_entry_uses_release_pack", False)),
        "generated_loadout_count": int(formal.get("full_sequence_generated_loadout_count", 0)),
        "fallback_loadout_count": int(formal.get("fallback_loadout_count", 0)),
        "reward_coverage_complete": bool(reward.get("all_generated_slots_have_reward", False)),
        "sequence_balance_pass": bool(balance.get("sequence_balance_pass", False)),
        "weapon_followup_runtime_ready": bool(followup.get("probe_pass", False)),
        "rollback_to_fallback_ready": bool(channels.get("rollback_to_fallback_ready", False)),
        "rollback_to_previous_current_ready": previous_ready,
        "smoke_pass": False,
    }
    report["smoke_pass"] = (
        report["current_release_points_to_balanced_pack"]
        and report["active_profile_points_to_balanced_pack"]
        and report["formal_entry_uses_balanced_release"]
        and report["generated_loadout_count"] == 15
        and report["fallback_loadout_count"] == 0
        and report["reward_coverage_complete"]
        and report["sequence_balance_pass"]
        and report["weapon_followup_runtime_ready"]
        and report["rollback_to_fallback_ready"]
        and report["rollback_to_previous_current_ready"]
    )
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(build_markdown(report), encoding="utf-8")
    return report


def previous_current_ready(profile_id: str, content_pack_id: str) -> bool:
    path = ROOT / "data" / "aigc_battle" / "generated" / "balance_release" / "balance_release_evaluation_report.json"
    if not path.exists():
        return False
    payload = read_json(path)
    source_profile_id = str(payload.get("source_profile_id", ""))
    source_pack_id = str(payload.get("source_pack_id", ""))
    if not source_profile_id or not source_pack_id:
        return False
    if source_profile_id == profile_id and source_pack_id == content_pack_id:
        return False
    try:
        release_lib.validate_release_pack(source_profile_id, source_pack_id, allow_archived=False)
    except SystemExit:
        return False
    return True


def build_markdown(report: dict[str, Any]) -> str:
    lines = ["# Balance Release Smoke Report", ""]
    for key in [
        "current_release_points_to_balanced_pack",
        "active_profile_points_to_balanced_pack",
        "formal_entry_uses_balanced_release",
        "generated_loadout_count",
        "fallback_loadout_count",
        "reward_coverage_complete",
        "sequence_balance_pass",
        "weapon_followup_runtime_ready",
        "rollback_to_fallback_ready",
        "rollback_to_previous_current_ready",
        "smoke_pass",
    ]:
        lines.append(f"- {key}: `{report.get(key)}`")
    return "\n".join(lines) + "\n"


def run_serial(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
