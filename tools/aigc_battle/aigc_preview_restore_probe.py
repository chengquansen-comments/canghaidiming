#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import aigc_release_gate as release_lib

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "preview_runtime"
PREVIEW_HISTORY_PATH = ROOT / "data" / "aigc_battle" / "preview" / "preview_history.jsonl"


def main(argv: list[str]) -> int:
    _ = argv
    result = run_probe()
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result.get("probe_pass", False) else 1


def run_probe() -> dict[str, Any]:
    selected = choose_preview_target()
    current_before = release_lib.show_channels().get("current_release", {})
    preview_lib.set_preview(selected["mechanic_profile_id"], selected["content_pack_id"], started_by="preview_restore_probe", reason="failure restore probe")
    preview_lib.mark_preview_failed("simulated preview failure")
    restore = preview_lib.restore_current()
    current_after = release_lib.show_channels().get("current_release", {})
    history_lines = PREVIEW_HISTORY_PATH.read_text(encoding="utf-8").splitlines() if PREVIEW_HISTORY_PATH.exists() else []
    payload = {
        "generated_at": now_iso(),
        "preview_failure_simulated": True,
        "restore_after_failure_ready": bool(restore.get("restore_current_ready", False)),
        "current_release_unchanged": current_before == current_after,
        "active_profile_restored": bool(restore.get("active_profile_matches_current_release", False)),
        "preview_history_written": any('"action": "preview_failed"' in line for line in history_lines) and any('"action": "restore_current"' in line for line in history_lines),
        "probe_pass": (
            bool(restore.get("restore_current_ready", False))
            and current_before == current_after
            and bool(restore.get("active_profile_matches_current_release", False))
            and any('"action": "preview_failed"' in line for line in history_lines)
            and any('"action": "restore_current"' in line for line in history_lines)
        ),
    }
    write_json(OUT_DIR / "preview_restore_probe_report.json", payload)
    (OUT_DIR / "preview_restore_probe_report.md").write_text(build_markdown(payload), encoding="utf-8")
    return payload


def choose_preview_target() -> dict[str, Any]:
    listing = preview_lib.list_previewable_packs()
    for preferred in [
        ("weapon_followup_v0_1", "r9_fast_candidate_pack_001"),
        ("weapon_followup_v0_1", "weapon_followup_v0_1__formal_sequence_12_fast_v1__hardened_013"),
        ("weapon_followup_v0_1", "weapon_followup_v0_1__formal_sequence_12_fast_v1__matrix_001"),
    ]:
        for item in listing.get("packs", []):
            if str(item.get("mechanic_profile_id", "")) == preferred[0] and str(item.get("content_pack_id", "")) == preferred[1]:
                return item
    if listing.get("packs"):
        return listing["packs"][0]
    raise SystemExit("no previewable pack available")


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join([
        "# Preview Restore Probe Report",
        "",
        f"- preview_failure_simulated: `{payload.get('preview_failure_simulated', False)}`",
        f"- restore_after_failure_ready: `{payload.get('restore_after_failure_ready', False)}`",
        f"- current_release_unchanged: `{payload.get('current_release_unchanged', False)}`",
        f"- active_profile_restored: `{payload.get('active_profile_restored', False)}`",
        f"- preview_history_written: `{payload.get('preview_history_written', False)}`",
        f"- probe_pass: `{payload.get('probe_pass', False)}`",
        "",
    ]) + "\n"


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
