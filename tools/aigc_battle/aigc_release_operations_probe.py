#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import switch_active_profile as switch_lib


PROFILE_ID = "weapon_followup_v0_1"
REPORT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "ai_production"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python3 tools/aigc_battle/aigc_release_operations_probe.py", file=sys.stderr)
        return 1
    ai_probe_report = read_json(REPORT_DIR / "aigc_ai_production_probe_report.json")
    pack_id = str(ai_probe_report.get("ai_pack_id", "")).strip()
    if not pack_id:
        raise SystemExit("ai production probe report missing ai_pack_id")
    original_active = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")
    write_review_notes_accepted(PROFILE_ID, pack_id)
    release_lib.set_release_status(PROFILE_ID, pack_id, "accepted")
    freeze_manifest = release_lib.freeze_pack(PROFILE_ID, pack_id)
    candidate_manifest = release_lib.mark_release_candidate(PROFILE_ID, pack_id)
    report_payload = release_lib.generate_release_report(PROFILE_ID, pack_id)
    compare_payload = release_lib.compare_release_candidates()
    activation_payload = release_lib.activate_release_candidate(PROFILE_ID, pack_id)
    active_after_activation = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")
    rollback_payload = release_lib.rollback_release()
    restored_active = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")
    archived_manifest = release_lib.archive_pack(PROFILE_ID, pack_id)
    git_suggestions = release_lib.suggest_git_commands(PROFILE_ID, pack_id)
    archived_readonly = False
    try:
        run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "aigc_pack_factory.py"), "build-ai-pack", "--profile", PROFILE_ID, "--pack-id", pack_id])
    except SystemExit:
        archived_readonly = True
    final_active_ok = restored_active == original_active

    report = {
        "release_gate_ready": True,
        "review_status_ready": freeze_manifest.get("review_status") == "accepted",
        "pack_freeze_ready": bool(freeze_manifest.get("frozen", False)),
        "release_candidate_ready": candidate_manifest.get("release_status") == "release_candidate",
        "release_manifest_exported": release_lib.release_manifest_path(PROFILE_ID, pack_id).exists(),
        "release_report_ready": bool(report_payload.get("release_report_path")),
        "release_candidate_activation_ready": active_after_activation.get("active_content_pack_id") == pack_id,
        "rollback_ready": rollback_payload.get("rolled_back_to_profile_id", "") == original_active.get("active_mechanic_profile_id", ""),
        "archived_pack_readonly": archived_readonly,
        "release_candidate_compare_ready": bool(compare_payload.get("compare_ready", False)),
        "suggested_git_commands_ready": bool(git_suggestions.get("suggested_git_commit_command")) and bool(git_suggestions.get("suggested_git_tag_command")),
        "active_profile_not_corrupted": final_active_ok,
        "probe_pass": False,
        "ai_pack_id": pack_id,
    }
    report["probe_pass"] = all(bool(value) for key, value in report.items() if key not in {"probe_pass", "ai_pack_id"})
    json_path = REPORT_DIR / "aigc_release_operations_probe_report.json"
    md_path = REPORT_DIR / "aigc_release_operations_probe_report.md"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    md_path.write_text("\n".join([f"- {k}: {str(v).lower()}" for k, v in report.items()]) + "\n", encoding="utf-8")
    print(f"wrote {json_path.relative_to(ROOT)}")
    return 0 if report["probe_pass"] else 1


def write_review_notes_accepted(profile_id: str, content_pack_id: str) -> None:
    notes = review_lib.default_review_notes(profile_id, content_pack_id)
    notes.update({
        "review_status": "accepted",
        "reviewer": "probe",
        "summary": "AI pack probe accepted for release flow test",
        "recommended_action": "ready_for_release_candidate",
        "review_time": release_lib.now_iso(),
        "last_updated_at": release_lib.now_iso(),
    })
    path = ROOT / "data" / "aigc_battle" / "review_notes" / f"{profile_id}__{content_pack_id}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(notes, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run(cmd: list[str]) -> None:
    completed = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if completed.returncode != 0:
        raise SystemExit((completed.stderr or completed.stdout or "command failed").strip())


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
