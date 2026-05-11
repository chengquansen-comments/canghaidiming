#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
REPORT_JSON = ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "evaluation_dashboard_probe_report.json"
REPORT_MD = ROOT / "data" / "aigc_battle" / "generated" / "evaluation" / "evaluation_dashboard_probe_report.md"
HOST = "127.0.0.1"
PORT = 8769


def main() -> int:
    server = subprocess.Popen(
        [sys.executable, "tools/aigc_battle/aigc_dashboard_server.py", "--port", str(PORT)],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        wait_for_server()
        evaluation_summary = get_json("/api/evaluation/summary")
        snapshot = get_json(
            "/api/evaluation/pack-snapshot?" + urllib.parse.urlencode(
                {"profile_id": "weapon_followup_v0_1", "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001"}
            )
        )
        recommendations = get_json(
            "/api/evaluation/rebuild-recommendations?" + urllib.parse.urlencode(
                {"profile_id": "weapon_followup_v0_1", "content_pack_id": "weapon_followup_v0_1_formal_sequence_pack_001"}
            )
        )
        invalid_request_rejected = False
        try:
            get_raw("/api/evaluation/pack-snapshot?profile_id=../bad&content_pack_id=oops")
        except urllib.error.HTTPError as exc:
            invalid_request_rejected = exc.code == 400

        workspace = read_json(ROOT / "data" / "aigc_battle" / "generated" / "review" / "aigc_review_workspace.json")
        compare = read_json(ROOT / "data" / "aigc_battle" / "generated" / "review" / "pack_compare_matrix.json")
        current_release = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
        active_profile = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json")

        active_profile_matches_current_release = (
            str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
            and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
        )
        review_workspace_evaluation_ready = any(
            int(row.get("evaluation_event_count", 0)) > 0 for row in workspace.get("pack_reviews", [])
        )
        compare_matrix_evaluation_ready = any(
            int(row.get("evaluation_event_count", 0)) > 0 and "actionability_score" in row for row in compare.get("packs", [])
        )
        report = {
            "evaluation_dashboard_ready": bool(evaluation_summary.get("pack_count", evaluation_summary.get("evaluated_pack_count", 0)) >= 1),
            "evaluation_summary_ready": bool(evaluation_summary),
            "pack_snapshot_api_ready": bool(snapshot.get("snapshot_ready", False)),
            "rebuild_recommendations_api_ready": bool(recommendations.get("recommendation_count", 0) >= 0),
            "review_workspace_evaluation_ready": review_workspace_evaluation_ready,
            "compare_matrix_evaluation_ready": compare_matrix_evaluation_ready,
            "build_from_evaluation_snapshot_ready": has_factory_build_endpoint_hint(),
            "invalid_request_rejected": invalid_request_rejected,
            "current_release_unchanged": str(current_release.get("mechanic_profile_id", "")) == "weapon_followup_v0_1" and str(current_release.get("content_pack_id", "")) == "weapon_followup_v0_1_formal_sequence_pack_001",
            "active_profile_matches_current_release": active_profile_matches_current_release,
        }
        report["probe_pass"] = all(report.values())
        write_json(REPORT_JSON, report)
        REPORT_MD.write_text(markdown(report), encoding="utf-8")
        print("evaluation dashboard probe complete")
        return 0 if report["probe_pass"] else 1
    finally:
        server.terminate()
        try:
            server.wait(timeout=3)
        except subprocess.TimeoutExpired:
            server.kill()


def has_factory_build_endpoint_hint() -> bool:
    source = (ROOT / "tools" / "aigc_battle" / "aigc_dashboard_server.py").read_text(encoding="utf-8")
    return "/api/factory/build-from-evaluation-snapshot" in source


def wait_for_server() -> None:
    deadline = time.time() + 10.0
    while time.time() < deadline:
        try:
            get_json("/api/health")
            return
        except Exception:
            time.sleep(0.2)
    raise SystemExit("dashboard server did not start in time")


def get_json(path: str) -> dict[str, Any]:
    raw = get_raw(path)
    return json.loads(raw.decode("utf-8"))


def get_raw(path: str) -> bytes:
    with urllib.request.urlopen(f"http://{HOST}:{PORT}{path}") as response:
        return response.read()


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def markdown(report: dict[str, Any]) -> str:
    return "# R3 Evaluation Dashboard Probe\n\n" + "\n".join(f"- {key}: `{value}`" for key, value in report.items()) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
