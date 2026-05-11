#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import threading
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_dashboard_server as dashboard_lib
from tools.aigc_battle import switch_active_profile as switch_lib


PROFILE_ID = "weapon_followup_v0_1"
SOURCE_PACK_ID = "weapon_followup_v0_1_formal_sequence_pack_001"
REPORT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "ai_production"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python3 tools/aigc_battle/aigc_p3_production_release_probe.py", file=sys.stderr)
        return 1
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    original_active = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")

    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_content_index.py")])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_detail_views.py")])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_review_workspace.py")])

    ai_report_path = REPORT_DIR / "aigc_ai_production_probe_report.json"
    if not ai_report_path.exists():
        run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "aigc_ai_production_probe.py")])
    release_report_path = REPORT_DIR / "aigc_release_operations_probe_report.json"
    if not release_report_path.exists():
        run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "aigc_release_operations_probe.py")])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_aigc_review_workspace.py")])

    ai_report = read_json(ai_report_path)
    release_report = read_json(release_report_path)
    api_report = probe_dashboard_api(str(ai_report.get("ai_pack_id", "")).strip())

    current_active = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")
    if current_active != original_active:
        switch_lib.switch_active_profile(
            str(original_active.get("active_mechanic_profile_id", "")),
            str(original_active.get("active_content_pack_id", "")) or None,
            switch_source="p3_probe_restore",
        )
    restored_active = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")

    report = {
        "ai_production_ready": bool(ai_report.get("probe_pass", False)),
        "llm_prompt_export_ready": bool(ai_report.get("llm_prompt_export_ready", False)),
        "llm_candidate_import_ready": bool(ai_report.get("llm_candidate_import_ready", False)),
        "invalid_llm_candidate_rejected": bool(ai_report.get("invalid_llm_candidate_rejected", False)),
        "valid_llm_pack_generated": bool(ai_report.get("valid_llm_pack_generated", False)),
        "review_workspace_shows_llm_source": bool(ai_report.get("review_workspace_shows_llm_source", False)),
        "release_operations_ready": bool(release_report.get("probe_pass", False)),
        "release_gate_ready": bool(release_report.get("release_gate_ready", False)),
        "pack_freeze_ready": bool(release_report.get("pack_freeze_ready", False)),
        "release_manifest_exported": bool(release_report.get("release_manifest_exported", False)),
        "rollback_ready": bool(release_report.get("rollback_ready", False)),
        "archived_pack_readonly": bool(release_report.get("archived_pack_readonly", False)),
        "dashboard_ai_release_api_ready": bool(api_report.get("api_ready", False)),
        "active_profile_not_corrupted": restored_active == original_active,
        "probe_pass": False,
    }
    report["probe_pass"] = all(bool(value) for key, value in report.items() if key != "probe_pass")
    json_path = REPORT_DIR / "aigc_p3_production_release_probe_report.json"
    md_path = REPORT_DIR / "aigc_p3_production_release_probe_report.md"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    md_path.write_text("\n".join([f"- {k}: {str(v).lower()}" for k, v in report.items()]) + "\n", encoding="utf-8")
    print(f"wrote {json_path.relative_to(ROOT)}")
    return 0 if report["probe_pass"] else 1


def probe_dashboard_api(ai_pack_id: str) -> dict[str, Any]:
    if not ai_pack_id:
        return {"api_ready": False}
    server = dashboard_lib.make_server("127.0.0.1", 0)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        base = f"http://127.0.0.1:{server.server_port}"
        prompt_payload = get_json(f"{base}/api/llm/prompt?profile_id={PROFILE_ID}&content_pack_id={SOURCE_PACK_ID}")
        diff_payload = get_json(f"{base}/api/llm/candidate-diff?profile_id={PROFILE_ID}")
        compare_payload = get_json(f"{base}/api/release/compare-candidates")
        git_payload = get_json(f"{base}/api/release/git-suggestions?profile_id={PROFILE_ID}&content_pack_id={ai_pack_id}")
        status_payload = get_json(f"{base}/api/release/status?profile_id={PROFILE_ID}&content_pack_id={ai_pack_id}")
        set_status_payload = post_json(
            f"{base}/api/release/set-status",
            {"profile_id": PROFILE_ID, "content_pack_id": ai_pack_id, "status": "accepted"},
        )
        invalid_rejected = False
        try:
            get_json(f"{base}/api/llm/prompt?profile_id=../bad&content_pack_id={SOURCE_PACK_ID}")
        except urllib.error.HTTPError as exc:
            invalid_rejected = exc.code == 400
        return {
            "api_ready": (
                prompt_payload.get("ok", True)
                and diff_payload.get("candidate_diff_ready", False)
                and compare_payload.get("compare_ready", False)
                and bool(git_payload.get("suggested_git_commit_command"))
                and bool(status_payload.get("content_pack_id"))
                and set_status_payload.get("ok", False)
                and invalid_rejected
            )
        }
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2.0)


def get_json(url: str) -> dict[str, Any]:
    with urllib.request.urlopen(url, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def post_json(url: str, payload: dict[str, Any]) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def run(cmd: list[str]) -> None:
    completed = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if completed.returncode != 0:
        raise SystemExit((completed.stderr or completed.stdout or "command failed").strip())


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
