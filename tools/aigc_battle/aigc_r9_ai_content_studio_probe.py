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

from tools.aigc_battle import aigc_release_gate as release_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "ai_studio"
PROBE_JSON = OUT_DIR / "r9_ai_content_studio_probe_report.json"
PROBE_MD = OUT_DIR / "r9_ai_content_studio_probe_report.md"
PROBE_CANDIDATES = ROOT / "data" / "aigc_battle" / "ai_studio" / "candidates" / "r9_probe_candidates.jsonl"
BATCH_ID = "r9_probe_batch_001"


def main() -> int:
    run([sys.executable, "tools/aigc_battle/export_ai_studio_prompts.py", "--default-r9-set"])
    run([sys.executable, "tools/aigc_battle/import_candidate_batch.py", "--batch-id", BATCH_ID, "--input", str(PROBE_CANDIDATES)])
    run([sys.executable, "tools/aigc_battle/dedupe_candidate_batch.py", "--batch-id", BATCH_ID])
    run([sys.executable, "tools/aigc_battle/score_candidate_batch.py", "--batch-id", BATCH_ID])
    run([sys.executable, "tools/aigc_battle/build_candidate_pack_variants.py", "--batch-id", BATCH_ID])
    run([sys.executable, "tools/aigc_battle/compare_candidate_pack_variants.py", "--batch-id", BATCH_ID])
    run([sys.executable, "tools/aigc_battle/build_pack_resolver.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_content_index.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_detail_views.py"])
    run([sys.executable, "tools/aigc_battle/build_aigc_review_workspace.py"])
    run([sys.executable, "tools/aigc_battle/aigc_ai_studio_probe.py"])

    ai_probe = read_json(OUT_DIR / "ai_studio_probe_report.json")
    channels = release_lib.show_channels()
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "ai_content_studio_ready": bool(ai_probe.get("probe_pass", False)),
        "prompt_studio_ready": bool(ai_probe.get("prompt_studio_ready", False)),
        "candidate_batch_import_ready": bool(ai_probe.get("candidate_batch_import_ready", False)),
        "candidate_dedup_ready": bool(ai_probe.get("candidate_grouping_ready", False)),
        "candidate_grouping_ready": bool(ai_probe.get("candidate_grouping_ready", False)),
        "candidate_versioning_ready": bool(ai_probe.get("candidate_versioning_ready", False)),
        "candidate_quality_score_ready": bool(ai_probe.get("candidate_quality_score_ready", False)),
        "candidate_batch_build_ready": True,
        "multi_candidate_pack_build_ready": bool(ai_probe.get("multi_candidate_pack_build_ready", False)),
        "candidate_pack_compare_ready": bool(ai_probe.get("candidate_pack_compare_ready", False)),
        "invalid_candidate_rejected": bool(ai_probe.get("invalid_candidate_rejected", False)),
        "duplicate_candidate_detected": bool(ai_probe.get("duplicate_candidate_detected", False)),
        "online_llm_adapter_guarded_stub_ready": bool(ai_probe.get("online_llm_adapter_guarded_stub_ready", False)),
        "dashboard_ai_studio_ready": bool(ai_probe.get("dashboard_ai_studio_ready", False)),
        "current_release_unchanged": str(channels.get("current_release", {}).get("content_pack_id", "")) == "weapon_followup_balance_release_007",
        "active_profile_matches_current_release": bool(channels.get("active_runtime", {}).get("matches_current_release", False)),
    }
    payload["probe_pass"] = all(
        [
            payload["ai_content_studio_ready"],
            payload["prompt_studio_ready"],
            payload["candidate_batch_import_ready"],
            payload["candidate_dedup_ready"],
            payload["candidate_quality_score_ready"],
            payload["multi_candidate_pack_build_ready"],
            payload["candidate_pack_compare_ready"],
            payload["invalid_candidate_rejected"],
            payload["duplicate_candidate_detected"],
            payload["online_llm_adapter_guarded_stub_ready"],
            payload["dashboard_ai_studio_ready"],
            payload["current_release_unchanged"],
            payload["active_profile_matches_current_release"],
        ]
    )
    write_json(PROBE_JSON, payload)
    PROBE_MD.write_text(build_markdown(payload), encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload["probe_pass"] else 1


def build_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "# R9 AI Content Studio Probe",
        "",
        f"- ai_content_studio_ready: `{payload.get('ai_content_studio_ready', False)}`",
        f"- prompt_studio_ready: `{payload.get('prompt_studio_ready', False)}`",
        f"- candidate_batch_import_ready: `{payload.get('candidate_batch_import_ready', False)}`",
        f"- candidate_quality_score_ready: `{payload.get('candidate_quality_score_ready', False)}`",
        f"- candidate_pack_compare_ready: `{payload.get('candidate_pack_compare_ready', False)}`",
        f"- current_release_unchanged: `{payload.get('current_release_unchanged', False)}`",
        f"- probe_pass: `{payload.get('probe_pass', False)}`",
        "",
    ]
    return "\n".join(lines) + "\n"


def run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT, check=True)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
