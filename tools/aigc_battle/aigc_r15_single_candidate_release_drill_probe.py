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

from tools.aigc_battle import aigc_release_switch_console as switch_lib


GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / "single_candidate_release_drill"
DRILL_REPORT_PATH = GENERATED_DIR / "single_candidate_release_drill_report.json"
PROBE_REPORT_PATH = GENERATED_DIR / "r15_single_candidate_release_drill_probe_report.json"
PROBE_MD_PATH = GENERATED_DIR / "r15_single_candidate_release_drill_probe_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"


def main(argv: list[str]) -> int:
    report = run_probe()
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report.get("probe_pass", False) else 1


def run_probe() -> dict[str, Any]:
    before_current = read_json(CURRENT_RELEASE_PATH)
    before_active = read_json(ACTIVE_PROFILE_PATH)
    before_fallback = read_json(FALLBACK_RELEASE_PATH)
    for command in [
        ["python3", "tools/aigc_battle/build_pack_resolver.py"],
        ["python3", "tools/aigc_battle/build_aigc_content_index.py"],
        ["python3", "tools/aigc_battle/build_aigc_detail_views.py"],
        ["python3", "tools/aigc_battle/build_aigc_review_workspace.py"],
        ["python3", "tools/aigc_battle/aigc_single_candidate_release_drill.py", "--target", "fast-run", "--samples", "2"],
        ["python3", "tools/aigc_battle/build_pack_resolver.py"],
        ["python3", "tools/aigc_battle/build_aigc_content_index.py"],
        ["python3", "tools/aigc_battle/build_aigc_detail_views.py"],
        ["python3", "tools/aigc_battle/build_aigc_review_workspace.py"],
    ]:
        subprocess.run(command, cwd=ROOT, check=True)

    drill = read_json(DRILL_REPORT_PATH)
    target_profile_id = str(drill.get("target_profile_id", ""))
    target_pack_id = str(drill.get("target_pack_id", ""))
    candidates = switch_lib.list_release_candidates()
    dry_run = switch_lib.set_current_release(target_profile_id, target_pack_id, dry_run=True, auto_smoke=False) if drill.get("marked_release_candidate", False) else {}
    after_current = read_json(CURRENT_RELEASE_PATH)
    after_active = read_json(ACTIVE_PROFILE_PATH)
    after_fallback = read_json(FALLBACK_RELEASE_PATH)

    report = {
        "generated_at": now_iso(),
        "single_candidate_release_drill_ready": bool(drill.get("single_candidate_release_drill_ready", False)),
        "selected_non_current_pack_ready": bool(target_pack_id) and target_pack_id != str(before_current.get("content_pack_id", "")),
        "target_pack_generated": bool(drill.get("target_pack_generated", False)),
        "target_pack_validated": bool(drill.get("target_pack_validated", False)),
        "target_pack_exported": bool(drill.get("target_pack_exported", False)),
        "target_preview_smoke_pass": bool(drill.get("preview_smoke_pass", False)),
        "target_acceptance_ready": bool(drill.get("acceptance_run_ready", False)),
        "target_acceptance_pass": bool(drill.get("acceptance_pass", False)),
        "human_review_note_ready": bool(drill.get("human_review_note_written", False)),
        "promotion_gate_checked": bool(drill.get("promotion_gate_checked", False)),
        "marked_release_candidate": bool(drill.get("marked_release_candidate", False)),
        "dry_run_switch_ready": bool(dry_run.get("switch_allowed", False) and dry_run.get("report_ready", False)),
        "actual_set_current": False,
        "formal_entry_smoke_pass": bool(drill.get("formal_entry_smoke_pass", False)),
        "rollback_previous_current_ready": bool(drill.get("rollback_previous_current_ready", False)),
        "rollback_fallback_ready": bool(drill.get("rollback_fallback_ready", False)),
        "current_release_unchanged": current_identity(before_current) == current_identity(after_current),
        "active_profile_matches_current_release": (
            str(after_active.get("active_mechanic_profile_id", "")) == str(after_current.get("mechanic_profile_id", ""))
            and str(after_active.get("active_content_pack_id", "")) == str(after_current.get("content_pack_id", ""))
        ),
        "fallback_release_unchanged": before_fallback == after_fallback,
        "partial_pass": bool(drill.get("partial_pass", False)),
    }
    report["probe_pass"] = all(
        [
            report["single_candidate_release_drill_ready"],
            report["selected_non_current_pack_ready"],
            report["target_pack_generated"],
            report["target_pack_validated"],
            report["target_pack_exported"],
            report["target_preview_smoke_pass"],
            report["target_acceptance_ready"],
            report["target_acceptance_pass"],
            report["human_review_note_ready"],
            report["promotion_gate_checked"],
            report["marked_release_candidate"],
            report["dry_run_switch_ready"],
            report["rollback_previous_current_ready"],
            report["rollback_fallback_ready"],
            report["current_release_unchanged"],
            report["active_profile_matches_current_release"],
            report["fallback_release_unchanged"],
        ]
    )
    write_json(PROBE_REPORT_PATH, report)
    PROBE_MD_PATH.write_text(build_markdown(report), encoding="utf-8")
    return report


def current_identity(payload: dict[str, Any]) -> tuple[str, str, str, str]:
    return (
        str(payload.get("mechanic_profile_id", "")),
        str(payload.get("content_pack_id", "")),
        str(payload.get("sequence_template_id", "")),
        str(payload.get("build_variant", "")),
    )


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_markdown(report: dict[str, Any]) -> str:
    lines = ["# R15 Single Candidate Release Drill Probe", ""]
    for key in [
        "single_candidate_release_drill_ready",
        "selected_non_current_pack_ready",
        "target_pack_generated",
        "target_pack_validated",
        "target_pack_exported",
        "target_preview_smoke_pass",
        "target_acceptance_ready",
        "target_acceptance_pass",
        "human_review_note_ready",
        "promotion_gate_checked",
        "marked_release_candidate",
        "dry_run_switch_ready",
        "rollback_previous_current_ready",
        "rollback_fallback_ready",
        "current_release_unchanged",
        "active_profile_matches_current_release",
        "fallback_release_unchanged",
        "partial_pass",
        "probe_pass",
    ]:
        lines.append(f"- {key}: `{report.get(key, False)}`")
    return "\n".join(lines) + "\n"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
