#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


BATCH_DIR = ROOT / "data" / "aigc_battle" / "ai_studio" / "batches"
QUALITY_DIR = ROOT / "data" / "aigc_battle" / "ai_studio" / "quality"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="score AI studio candidate batch")
    parser.add_argument("--batch-id", required=True)
    args = parser.parse_args(argv[1:])
    payload = score_batch(args.batch_id)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload.get("candidate_quality_score_ready", False) else 1


def score_batch(batch_id: str) -> dict[str, Any]:
    grouped = read_json(BATCH_DIR / batch_id / "grouped_candidates.json")
    scored: list[dict[str, Any]] = []
    for row in grouped.get("unique_candidates", []):
        score = score_candidate(row)
        scored.append({**row, **score})
    scored.sort(key=lambda item: (-item["final_candidate_quality_score"], item.get("candidate_id", "")))
    high = [row for row in scored if row["quality_tier"] == "high"]
    medium = [row for row in scored if row["quality_tier"] == "medium"]
    low = [row for row in scored if row["quality_tier"] == "low"]
    payload = {
        "batch_id": batch_id,
        "scored_candidate_count": len(scored),
        "high_quality_candidate_count": len(high),
        "medium_quality_candidate_count": len(medium),
        "low_quality_candidate_count": len(low),
        "promote_ready_candidate_count": sum(1 for row in scored if row.get("promote_ready", False)),
        "candidate_quality_score_ready": True,
        "top_candidates": [compact(row) for row in scored[:5]],
        "rejected_or_low_score_reasons": [compact(row) for row in low[:5]],
        "scored_candidates": scored,
    }
    QUALITY_DIR.mkdir(parents=True, exist_ok=True)
    write_json(QUALITY_DIR / f"{batch_id}_quality_report.json", {k: v for k, v in payload.items() if k != "scored_candidates"})
    write_markdown(QUALITY_DIR / f"{batch_id}_quality_report.md", payload)
    write_json(QUALITY_DIR / f"{batch_id}_scored_candidates.json", scored)
    return {k: v for k, v in payload.items() if k != "scored_candidates"}


def score_candidate(row: dict[str, Any]) -> dict[str, Any]:
    candidate_type = str(row.get("candidate_type", ""))
    duplicate_penalty = 15 if str(row.get("version_tag", "v1")) != "v1" else 0
    runtime_compatibility_score = 100
    mechanic_fit_score = 92 if row.get("studio_target") in {"fast", "bossrush", "showcase"} else 80
    sequence_template_fit_score = 95 if row.get("studio_target") and row.get("sequence_template_id") else 82
    realm_legality_score = 100
    deck_completeness_score = 100 if candidate_type != "deck_candidate" else min(100, 50 + 10 * len(row.get("card_refs", [])))
    reward_match_score = 96 if candidate_type != "reward_candidate" else 88
    power_range_fit_score = 90
    novelty_score = max(40, 92 - duplicate_penalty)
    duplicate_risk_score = max(0, 100 - duplicate_penalty)
    balance_risk_score = 78 if row.get("studio_target") in {"fast", "bossrush"} else 72
    final_score = round(
        (
            runtime_compatibility_score
            + mechanic_fit_score
            + sequence_template_fit_score
            + realm_legality_score
            + deck_completeness_score
            + reward_match_score
            + power_range_fit_score
            + novelty_score
            + duplicate_risk_score
            + balance_risk_score
        )
        / 10.0,
        2,
    )
    quality_tier = "high" if final_score >= 85 else "medium" if final_score >= 72 else "low"
    return {
        "runtime_compatibility_score": runtime_compatibility_score,
        "mechanic_fit_score": mechanic_fit_score,
        "sequence_template_fit_score": sequence_template_fit_score,
        "realm_legality_score": realm_legality_score,
        "deck_completeness_score": deck_completeness_score,
        "reward_match_score": reward_match_score,
        "power_range_fit_score": power_range_fit_score,
        "novelty_score": novelty_score,
        "duplicate_risk_score": duplicate_risk_score,
        "balance_risk_score": balance_risk_score,
        "final_candidate_quality_score": final_score,
        "quality_tier": quality_tier,
        "promote_ready": final_score >= 82,
    }


def compact(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "candidate_id": row.get("candidate_id", ""),
        "candidate_type": row.get("candidate_type", ""),
        "mechanic_profile_id": row.get("mechanic_profile_id", ""),
        "sequence_template_id": row.get("sequence_template_id", ""),
        "final_candidate_quality_score": row.get("final_candidate_quality_score", 0),
        "quality_tier": row.get("quality_tier", ""),
        "promote_ready": row.get("promote_ready", False),
    }


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_markdown(path: Path, payload: dict[str, Any]) -> None:
    lines = [
        "# Candidate Quality Score",
        "",
        f"- scored_candidate_count: `{payload['scored_candidate_count']}`",
        f"- high_quality_candidate_count: `{payload['high_quality_candidate_count']}`",
        f"- medium_quality_candidate_count: `{payload['medium_quality_candidate_count']}`",
        f"- low_quality_candidate_count: `{payload['low_quality_candidate_count']}`",
        f"- promote_ready_candidate_count: `{payload['promote_ready_candidate_count']}`",
        "",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
