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

from tools.aigc_battle import aigc_acceptance_run as acceptance_lib
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import switch_active_profile as switch_lib


PACK_RESOLVER_PATH = ROOT / "data" / "aigc_battle" / "pack_resolver.json"
PROMOTION_DIR = ROOT / "data" / "aigc_battle" / "promotion"
HUMAN_REVIEW_DIR = PROMOTION_DIR / "human_review_notes"
ALLOWED_STATUS = {"accepted", "rejected", "needs_balance", "pending"}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="write promotion human review note")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--pack", required=True)
    parser.add_argument("--status", required=True)
    parser.add_argument("--reviewer", required=True)
    parser.add_argument("--note", required=True)
    args = parser.parse_args(argv[1:])
    payload = write_human_review_note(args.profile, args.pack, args.status, args.reviewer, args.note)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


def write_human_review_note(profile_id: str, content_pack_id: str, status: str, reviewer: str, note: str) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(content_pack_id, "content_pack_id")
    if status not in ALLOWED_STATUS:
        raise SystemExit("invalid human review status")
    entry = resolve_pack(profile_id, content_pack_id)
    acceptance_path = acceptance_lib.acceptance_json_path(profile_id, content_pack_id)
    acceptance_report = preview_lib.read_json(acceptance_path) if acceptance_path.exists() else {}
    payload = {
        "mechanic_profile_id": profile_id,
        "content_pack_id": content_pack_id,
        "sequence_template_id": str(entry.get("sequence_template_id", "")),
        "build_variant": str(entry.get("build_variant", "")),
        "reviewer": str(reviewer).strip(),
        "status": status,
        "note": str(note).strip(),
        "created_at": now_iso(),
        "source_acceptance_report_path": acceptance_path.relative_to(ROOT).as_posix() if acceptance_report else "",
        "review_note_valid": True,
    }
    path = human_review_note_path(profile_id, content_pack_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload


def resolve_pack(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    resolver = preview_lib.read_required_json(PACK_RESOLVER_PATH)
    for entry in resolver.get("entries", []):
        if str(entry.get("mechanic_profile_id", "")) == profile_id and str(entry.get("content_pack_id", "")) == content_pack_id:
            return entry
    raise SystemExit("pack not found in pack_resolver")


def human_review_note_path(profile_id: str, content_pack_id: str) -> Path:
    return HUMAN_REVIEW_DIR / f"{profile_id}__{content_pack_id}.json"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
