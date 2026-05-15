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


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "ai_studio"
PROMPTS = ROOT / "data" / "aigc_battle" / "ai_studio" / "prompts" / "r9_prompt_manifest.json"
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

    prompt_manifest = read_json(PROMPTS)
    import_report = read_json(ROOT / "data" / "aigc_battle" / "ai_studio" / "batches" / BATCH_ID / "import_report.json")
    dedupe_report = read_json(ROOT / "data" / "aigc_battle" / "ai_studio" / "batches" / BATCH_ID / "dedupe_report.json")
    quality_report = read_json(ROOT / "data" / "aigc_battle" / "ai_studio" / "quality" / f"{BATCH_ID}_quality_report.json")
    build_report = read_json(OUT_DIR / "r9_candidate_pack_build_report.json")
    compare_report = read_json(OUT_DIR / "r9_candidate_pack_compare_report.json")
    channels = release_lib.show_channels()
    dashboard_ready = dashboard_api_ready()
    current_unchanged = str(channels.get("current_release", {}).get("content_pack_id", "")) == "weapon_followup_balance_release_007"

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "prompt_studio_ready": bool(prompt_manifest.get("prompt_studio_ready", False)),
        "candidate_batch_import_ready": bool(import_report.get("ready_for_quality_score", False)),
        "invalid_candidate_rejected": bool(import_report.get("rejected_candidate_count", 0) > 0 and import_report.get("unsupported_effect_rejected", 0) > 0),
        "duplicate_candidate_detected": bool(dedupe_report.get("duplicate_candidate_count", 0) > 0),
        "candidate_grouping_ready": bool(dedupe_report.get("candidate_grouping_ready", False)),
        "candidate_versioning_ready": bool(dedupe_report.get("candidate_versioning_ready", False)),
        "candidate_quality_score_ready": bool(quality_report.get("candidate_quality_score_ready", False)),
        "promote_ready_candidates_found": bool(quality_report.get("promote_ready_candidate_count", 0) > 0),
        "multi_candidate_pack_build_ready": bool(build_report.get("ai_studio_pack_build_ready", False)),
        "candidate_pack_compare_ready": bool(compare_report.get("candidate_pack_compare_ready", False)),
        "dashboard_ai_studio_ready": dashboard_ready,
        "online_llm_adapter_guarded_stub_ready": bool(prompt_manifest.get("online_llm_adapter_supported", False) is False),
        "llm_never_writes_runtime_manifest": bool(prompt_manifest.get("llm_never_writes_runtime_manifest", False)),
        "llm_never_writes_active_profile": bool(prompt_manifest.get("llm_never_writes_active_profile", False)),
        "current_release_unchanged": current_unchanged,
    }
    payload["probe_pass"] = all(
        [
            payload["prompt_studio_ready"],
            payload["candidate_batch_import_ready"],
            payload["invalid_candidate_rejected"],
            payload["duplicate_candidate_detected"],
            payload["candidate_grouping_ready"],
            payload["candidate_versioning_ready"],
            payload["candidate_quality_score_ready"],
            payload["multi_candidate_pack_build_ready"],
            payload["candidate_pack_compare_ready"],
            payload["dashboard_ai_studio_ready"],
            payload["online_llm_adapter_guarded_stub_ready"],
            payload["llm_never_writes_runtime_manifest"],
            payload["llm_never_writes_active_profile"],
            payload["current_release_unchanged"],
        ]
    )
    write_json(OUT_DIR / "ai_studio_probe_report.json", payload)
    (OUT_DIR / "ai_studio_probe_report.md").write_text(build_markdown(payload), encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload["probe_pass"] else 1


def dashboard_api_ready() -> bool:
    try:
        return bool(
            dashboard_lib.load_ai_studio_summary()
            and dashboard_lib.load_ai_studio_prompts()
            and dashboard_lib.load_ai_studio_batches()
            and dashboard_lib.load_ai_studio_quality()
            and dashboard_lib.load_ai_studio_pack_compare()
        )
    except Exception:
        return False


def build_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "# AI Studio Probe",
        "",
        f"- prompt_studio_ready: `{payload.get('prompt_studio_ready', False)}`",
        f"- candidate_batch_import_ready: `{payload.get('candidate_batch_import_ready', False)}`",
        f"- invalid_candidate_rejected: `{payload.get('invalid_candidate_rejected', False)}`",
        f"- duplicate_candidate_detected: `{payload.get('duplicate_candidate_detected', False)}`",
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
