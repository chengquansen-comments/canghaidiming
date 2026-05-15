#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


STUDIO_BATCH_DIR = ROOT / "data" / "aigc_battle" / "ai_studio" / "batches"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="dedupe AI studio batch")
    parser.add_argument("--batch-id", required=True)
    args = parser.parse_args(argv[1:])
    payload = dedupe_batch(args.batch_id)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload.get("candidate_grouping_ready", False) else 1


def dedupe_batch(batch_id: str) -> dict[str, Any]:
    batch_dir = STUDIO_BATCH_DIR / batch_id
    accepted = read_jsonl(batch_dir / "accepted_candidates.jsonl")
    signature_counts: Counter[str] = Counter()
    unique_candidates: list[dict[str, Any]] = []
    groups_by_mechanic: defaultdict[str, list[str]] = defaultdict(list)
    groups_by_template: defaultdict[str, list[str]] = defaultdict(list)
    groups_by_type: defaultdict[str, list[str]] = defaultdict(list)

    for row in accepted:
        signature = build_signature(row)
        signature_counts[signature] += 1
        version_tag = f"v{signature_counts[signature]}"
        enriched = dict(row)
        enriched["candidate_signature"] = signature
        enriched["version_tag"] = version_tag
        groups_by_mechanic[str(row.get("mechanic_profile_id", ""))].append(str(row.get("candidate_id", "")))
        groups_by_template[str(row.get("sequence_template_id", ""))].append(str(row.get("candidate_id", "")))
        groups_by_type[str(row.get("candidate_type", ""))].append(str(row.get("candidate_id", "")))
        if signature_counts[signature] == 1:
            unique_candidates.append(enriched)

    payload = {
        "batch_id": batch_id,
        "duplicate_candidate_count": len(accepted) - len(unique_candidates),
        "unique_candidate_count": len(unique_candidates),
        "groups_by_mechanic": {key: len(value) for key, value in groups_by_mechanic.items()},
        "groups_by_template": {key: len(value) for key, value in groups_by_template.items()},
        "groups_by_type": {key: len(value) for key, value in groups_by_type.items()},
        "candidate_versioning_ready": True,
        "candidate_grouping_ready": True,
        "unique_candidates": unique_candidates,
    }
    write_json(batch_dir / "grouped_candidates.json", payload)
    write_json(batch_dir / "dedupe_report.json", {k: v for k, v in payload.items() if k != "unique_candidates"})
    return {k: v for k, v in payload.items() if k != "unique_candidates"}


def build_signature(candidate: dict[str, Any]) -> str:
    filtered = {
        key: value
        for key, value in candidate.items()
        if key not in {"candidate_id", "version_tag", "candidate_signature", "notes", "created_at"}
    }
    return json.dumps(filtered, ensure_ascii=False, sort_keys=True)


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        clean = line.strip()
        if clean:
            rows.append(json.loads(clean))
    return rows


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
