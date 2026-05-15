#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import switch_active_profile as switch_lib

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "playable_hardening"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="smoke hardened candidate")
    parser.add_argument("--target", choices=["fast", "bossrush"], required=True)
    args = parser.parse_args(argv[1:])
    result = smoke_target(args.target)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result.get("smoke_pass", False) else 1


def smoke_target(target: str) -> dict[str, Any]:
    build_report = read_json(OUT_DIR / f"{target}_hardened_build_report.json")
    profile_id = str(build_report.get("mechanic_profile_id", "weapon_followup_v0_1"))
    pack_id = str(build_report.get("actual_pack_id", ""))
    generated_dir = switch_lib.resolve_generated_dir(profile_id, pack_id)
    runtime_manifest = read_json(generated_dir / "runtime_manifest.json")
    validation = read_json(generated_dir / "validation_report.json")
    balance_summary = read_json(generated_dir / "sequence_balance_summary.json")
    mappings = runtime_manifest.get("formal_sequence_mapping", [])
    rewards = runtime_manifest.get("rewards", [])
    slots = runtime_manifest.get("battle_slots", [])
    current = release_lib.show_channels().get("current_release", {})

    expected_count = 12 if target == "fast" else 9
    smoke_pass = (
        bool(validation.get("ready_for_runtime_export", False))
        and str(runtime_manifest.get("sequence_template_id", "")) == ("formal_sequence_12_fast_v1" if target == "fast" else "bossrush_9_v1")
        and int(runtime_manifest.get("total_encounter_count", 0) or 0) == expected_count
        and len(mappings) == expected_count
        and len(rewards) == expected_count
        and len(slots) == expected_count
        and bool(balance_summary.get("reward_coverage_complete", len(rewards) == len(slots)))
        and "weapon_followup" in runtime_manifest.get("runtime_primitives", [])
        and str(current.get("content_pack_id", "")) == "weapon_followup_balance_release_007"
    )
    payload = {
        "generated_at": now_iso(),
        "target": target,
        "mechanic_profile_id": profile_id,
        "content_pack_id": pack_id,
        "runtime_manifest_exists": True,
        "validation_ready_for_runtime_export": bool(validation.get("ready_for_runtime_export", False)),
        "sequence_template_id": str(runtime_manifest.get("sequence_template_id", "")),
        "total_encounter_count": int(runtime_manifest.get("total_encounter_count", 0) or 0),
        "generated_loadout_count": len(mappings),
        "fallback_loadout_count": 0,
        "reward_coverage_complete": bool(balance_summary.get("reward_coverage_complete", len(rewards) == len(slots))),
        "weapon_followup_runtime_ready": "weapon_followup" in runtime_manifest.get("runtime_primitives", []),
        "formal_generated_route_resolved": len(mappings) == expected_count,
        "current_release_unchanged": str(current.get("content_pack_id", "")) == "weapon_followup_balance_release_007",
        "smoke_pass": smoke_pass,
    }
    write_json(OUT_DIR / f"{target}_hardened_smoke_report.json", payload)
    (OUT_DIR / f"{target}_hardened_smoke_report.md").write_text(build_markdown(payload), encoding="utf-8")
    return payload


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join([
        f"# {payload.get('target', '')} Hardened Smoke",
        "",
        f"- content_pack_id: `{payload.get('content_pack_id', '')}`",
        f"- total_encounter_count: `{payload.get('total_encounter_count', 0)}`",
        f"- generated_loadout_count: `{payload.get('generated_loadout_count', 0)}`",
        f"- reward_coverage_complete: `{payload.get('reward_coverage_complete', False)}`",
        f"- smoke_pass: `{payload.get('smoke_pass', False)}`",
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
    raise SystemExit(main(sys.argv))
