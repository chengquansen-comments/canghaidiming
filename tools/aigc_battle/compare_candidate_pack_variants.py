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

from tools.aigc_battle import aigc_headless_evaluation_runner as eval_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "ai_studio"
BUILD_REPORT = OUT_DIR / "r9_candidate_pack_build_report.json"
COMPARE_JSON = OUT_DIR / "r9_candidate_pack_compare_report.json"
COMPARE_MD = OUT_DIR / "r9_candidate_pack_compare_report.md"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="compare AI studio candidate pack variants")
    parser.add_argument("--batch-id", required=True)
    args = parser.parse_args(argv[1:])
    payload = compare_candidate_pack_variants(args.batch_id)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload.get("candidate_pack_compare_ready", False) else 1


def compare_candidate_pack_variants(batch_id: str) -> dict[str, Any]:
    build_report = read_json(BUILD_REPORT)
    rows: list[dict[str, Any]] = []
    for variant in build_report.get("built_variants", []):
        report = eval_lib.evaluate_pack(str(variant.get("mechanic_profile_id", "")), str(variant.get("content_pack_id", "")), 2)
        pack_metrics = report.get("pack_metrics", {})
        rows.append(
            {
                "mechanic_profile_id": variant.get("mechanic_profile_id", ""),
                "sequence_template_id": variant.get("sequence_template_id", ""),
                "content_pack_id": variant.get("content_pack_id", ""),
                "total_encounter_count": report.get("formal_encounter_total_count", 0),
                "evaluation_event_count": report.get("evaluation_event_count", 0),
                "win_rate": float(pack_metrics.get("win_rate", 0) or 0),
                "avg_turn_count": float(pack_metrics.get("avg_turn_count", 0) or 0),
                "avg_player_hp_end": float(pack_metrics.get("avg_player_hp_end", 0) or 0),
                "runtime_primitive_trigger_rate": float(pack_metrics.get("runtime_primitive_trigger_rate", 0) or 0),
                "mechanic_trigger_rate": float(pack_metrics.get("runtime_primitive_trigger_rate", 0) or 0),
            }
        )
    best = max(rows, key=lambda item: (min(item["win_rate"], 0.85), -abs(0.65 - item["win_rate"]), -item["avg_turn_count"])) if rows else {}
    fastest = min(rows, key=lambda item: (item["avg_turn_count"], -item["win_rate"])) if rows else {}
    safest = max(rows, key=lambda item: (item["win_rate"], item["avg_player_hp_end"])) if rows else {}
    highest_fit = max(rows, key=lambda item: (item["mechanic_trigger_rate"], item["win_rate"])) if rows else {}
    ready = [row["content_pack_id"] for row in rows if 0.25 <= row["win_rate"] <= 0.9]
    needing_balance = [row["content_pack_id"] for row in rows if row["content_pack_id"] not in ready]
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "batch_id": batch_id,
        "compared_pack_count": len(rows),
        "evaluated_pack_count": len(rows),
        "best_candidate_pack": pack_ref(best),
        "fastest_candidate_pack": pack_ref(fastest),
        "safest_candidate_pack": pack_ref(safest),
        "highest_mechanic_fit_pack": pack_ref(highest_fit),
        "candidate_packs_needing_balance": needing_balance,
        "candidate_packs_ready_for_review": ready,
        "candidate_pack_compare_ready": True,
        "rows": rows,
    }
    write_json(COMPARE_JSON, payload)
    COMPARE_MD.write_text(build_markdown(payload), encoding="utf-8")
    return payload


def pack_ref(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "mechanic_profile_id": row.get("mechanic_profile_id", ""),
        "sequence_template_id": row.get("sequence_template_id", ""),
        "content_pack_id": row.get("content_pack_id", ""),
    }


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join(
        [
            "# Candidate Pack Compare",
            "",
            f"- compared_pack_count: `{payload.get('compared_pack_count', 0)}`",
            f"- best_candidate_pack: `{payload.get('best_candidate_pack', {}).get('content_pack_id', '')}`",
            f"- fastest_candidate_pack: `{payload.get('fastest_candidate_pack', {}).get('content_pack_id', '')}`",
            f"- safest_candidate_pack: `{payload.get('safest_candidate_pack', {}).get('content_pack_id', '')}`",
            "",
        ]
    ) + "\n"


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
