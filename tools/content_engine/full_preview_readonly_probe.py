#!/usr/bin/env python3
"""v1.7 full preview Python readonly probe。"""

from __future__ import annotations

import csv
import json
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

MANIFEST = Path("data/runtime_preview/content_engine/full_content_package.preview_manifest.json")
OUT = Path("data/design/generated_full_preview_readonly_probe_report.tsv")
FIELDS = [
    "check_id",
    "status",
    "expected",
    "actual",
    "notes",
]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def atomic_write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{uuid.uuid4().hex}.tmp")
    with tmp.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def main() -> int:
    if not MANIFEST.exists():
        raise FileNotFoundError("missing full preview manifest")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    domains = manifest.get("domains", []) if isinstance(manifest, dict) else []
    domain_map: dict[str, dict] = {}
    if isinstance(domains, list):
        for d in domains:
            if isinstance(d, dict):
                domain_map[str(d.get("domain", ""))] = d

    required = [
        "battle_rewards",
        "battle_slots",
        "enemy_decks",
        "card_pool",
        "operation_nodes",
        "narrative_nodes",
        "route_gates",
    ]

    rows: list[dict[str, str]] = []
    rows.append(
        {
            "check_id": "manifest_runtime_ready",
            "status": "PASS" if manifest.get("runtime_ready") is False else "FAIL",
            "expected": "false",
            "actual": str(manifest.get("runtime_ready", "unknown")).lower(),
            "notes": "full preview manifest 必须 runtime_ready=false",
        }
    )
    rows.append(
        {
            "check_id": "manifest_preview_only",
            "status": "PASS" if manifest.get("preview_only") is True else "FAIL",
            "expected": "true",
            "actual": str(manifest.get("preview_only", "unknown")).lower(),
            "notes": "full preview manifest 必须 preview_only=true",
        }
    )
    for key in required:
        item = domain_map.get(key, {})
        p = Path(str(item.get("path", ""))) if item else Path("")
        exists = p.exists() if item else False
        rows.append(
            {
                "check_id": f"domain_path_exists::{key}",
                "status": "PASS" if exists else "FAIL",
                "expected": "true",
                "actual": str(exists).lower(),
                "notes": str(p) if item else "missing_domain_entry",
            }
        )

    rows.append(
        {
            "check_id": "selected_reward_policy",
            "status": "PASS" if manifest.get("selected_reward_policy") == "legacy" else "FAIL",
            "expected": "legacy",
            "actual": str(manifest.get("selected_reward_policy", "")),
            "notes": "selected_reward_policy 必须 legacy",
        }
    )
    rows.append(
        {
            "check_id": "content_engine_enabled",
            "status": "PASS" if manifest.get("content_engine_enabled") is False else "FAIL",
            "expected": "false",
            "actual": str(manifest.get("content_engine_enabled", "unknown")).lower(),
            "notes": "content_engine_enabled 必须 false",
        }
    )
    rows.append(
        {
            "check_id": "generated_at",
            "status": "PASS",
            "expected": "iso8601",
            "actual": now_iso(),
            "notes": "probe 生成时间",
        }
    )

    atomic_write_tsv(OUT, rows)
    ok = all(r["status"] == "PASS" for r in rows)
    print(f"Wrote {OUT.as_posix()} rows={len(rows)} status={'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
