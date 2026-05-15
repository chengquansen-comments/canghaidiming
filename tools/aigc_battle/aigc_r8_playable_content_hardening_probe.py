#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_dashboard_server as dashboard_lib
from tools.aigc_battle import aigc_release_gate as release_lib

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "playable_hardening"
REPORT_JSON = OUT_DIR / "r8_playable_content_hardening_probe_report.json"
REPORT_MD = OUT_DIR / "r8_playable_content_hardening_probe_report.md"


def main() -> int:
    run([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])
    run([sys.executable, "tools/aigc_battle/build_playable_hardening_plan.py"])
    run([sys.executable, "tools/aigc_battle/aigc_build_hardened_candidate.py", "--target", "fast"])
    run([sys.executable, "tools/aigc_battle/aigc_build_hardened_candidate.py", "--target", "bossrush"])
    run([sys.executable, "tools/aigc_battle/evaluate_hardened_candidates.py", "--samples", "4"])
    run([sys.executable, "tools/aigc_battle/aigc_hardened_candidate_smoke_probe.py", "--target", "fast"])
    run([sys.executable, "tools/aigc_battle/aigc_hardened_candidate_smoke_probe.py", "--target", "bossrush"])

    evaluation = read_json(OUT_DIR / "hardened_candidates_evaluation_report.json")
    fast_smoke = read_json(OUT_DIR / "fast_hardened_smoke_report.json")
    boss_smoke = read_json(OUT_DIR / "bossrush_hardened_smoke_report.json")
    fast_build = read_json(OUT_DIR / "fast_hardened_build_report.json")
    boss_build = read_json(OUT_DIR / "bossrush_hardened_build_report.json")

    fast_marked = maybe_mark_release_candidate("fast", fast_build, evaluation, fast_smoke)
    boss_marked = maybe_mark_release_candidate("bossrush", boss_build, evaluation, boss_smoke)

    run([sys.executable, "tools/aigc_battle/build_pack_resolver.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])

    dashboard_ready = dashboard_api_ready()
    channels = release_lib.show_channels()
    current_unchanged = str(channels.get("current_release", {}).get("content_pack_id", "")) == "weapon_followup_balance_release_007"
    active_matches = bool(channels.get("active_runtime", {}).get("matches_current_release", False))
    partial_pass = bool(
        (evaluation.get("fast_target_gate_pass", False) and fast_smoke.get("smoke_pass", False))
        ^ (evaluation.get("bossrush_target_gate_pass", False) and boss_smoke.get("smoke_pass", False))
    )
    probe_pass = bool(
        evaluation.get("fast_target_gate_pass", False)
        and evaluation.get("bossrush_target_gate_pass", False)
        and fast_smoke.get("smoke_pass", False)
        and boss_smoke.get("smoke_pass", False)
        and current_unchanged
        and active_matches
        and dashboard_ready
    )

    payload = {
        "generated_at": now_iso(),
        "playable_content_hardening_ready": probe_pass,
        "hardening_plan_ready": read_json(OUT_DIR / "playable_hardening_plan.json").get("playable_hardening_plan_ready", False),
        "fast_hardened_pack_generated": fast_build.get("hardened_pack_generated", False),
        "fast_hardened_pack_validated": fast_build.get("hardened_pack_validated", False),
        "fast_hardened_pack_exported": fast_build.get("hardened_pack_exported", False),
        "fast_hardened_pack_evaluated": True,
        "fast_target_gate_pass": evaluation.get("fast_target_gate_pass", False),
        "fast_smoke_pass": fast_smoke.get("smoke_pass", False),
        "fast_marked_release_candidate": fast_marked,
        "bossrush_hardened_pack_generated": boss_build.get("hardened_pack_generated", False),
        "bossrush_hardened_pack_validated": boss_build.get("hardened_pack_validated", False),
        "bossrush_hardened_pack_exported": boss_build.get("hardened_pack_exported", False),
        "bossrush_hardened_pack_evaluated": True,
        "bossrush_target_gate_pass": evaluation.get("bossrush_target_gate_pass", False),
        "bossrush_smoke_pass": boss_smoke.get("smoke_pass", False),
        "bossrush_marked_release_candidate": boss_marked,
        "current_release_reference_still_playable": evaluation.get("current_release_reference_still_playable", False),
        "current_release_unchanged": current_unchanged,
        "active_profile_matches_current_release": active_matches,
        "dashboard_playable_hardening_ready": dashboard_ready,
        "partial_pass": partial_pass,
        "probe_pass": probe_pass,
    }
    write_json(REPORT_JSON, payload)
    REPORT_MD.write_text(build_markdown(payload), encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if probe_pass else 1


def maybe_mark_release_candidate(target: str, build: dict[str, Any], evaluation: dict[str, Any], smoke: dict[str, Any]) -> bool:
    gate_key = "fast_target_gate_pass" if target == "fast" else "bossrush_target_gate_pass"
    if not evaluation.get(gate_key, False) or not smoke.get("smoke_pass", False):
        return False
    profile_id = str(build.get("mechanic_profile_id", "weapon_followup_v0_1"))
    pack_id = str(build.get("actual_pack_id", ""))
    release_lib.set_release_status(profile_id, pack_id, "accepted")
    release_lib.freeze_pack(profile_id, pack_id)
    release_lib.mark_release_candidate(profile_id, pack_id)
    return True


def dashboard_api_ready() -> bool:
    try:
        return bool(dashboard_lib.load_playable_hardening_summary() and dashboard_lib.load_playable_hardening_evaluation() and dashboard_lib.load_playable_hardening_strategy())
    except Exception:
        return False


def run(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join([
        "# R8 Playable Content Hardening Probe",
        "",
        f"- fast_target_gate_pass: `{payload.get('fast_target_gate_pass', False)}`",
        f"- bossrush_target_gate_pass: `{payload.get('bossrush_target_gate_pass', False)}`",
        f"- current_release_unchanged: `{payload.get('current_release_unchanged', False)}`",
        f"- dashboard_playable_hardening_ready: `{payload.get('dashboard_playable_hardening_ready', False)}`",
        f"- partial_pass: `{payload.get('partial_pass', False)}`",
        f"- probe_pass: `{payload.get('probe_pass', False)}`",
        "",
    ]) + "\n"


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main())
