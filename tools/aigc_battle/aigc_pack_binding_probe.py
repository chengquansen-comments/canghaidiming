#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_release_gate as release_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "sequence_template_validation"
REPORT_JSON = OUT_DIR / "pack_binding_probe_report.json"
REPORT_MD = OUT_DIR / "pack_binding_probe_report.md"
FORMAL12FAST_PACK_ID = "weapon_followup_v0_1__formal_sequence_12_fast_v1__baseline_001"


def main() -> int:
    current = release_lib.read_release_channel("current", required=True)
    fallback = release_lib.read_release_channel("fallback", required=True)
    resolver = read_json(ROOT / "data" / "aigc_battle" / "pack_resolver.json")
    entries = resolver.get("entries", [])
    current_entry = find_entry(entries, str(current.get("mechanic_profile_id", "")), str(current.get("content_pack_id", "")))
    fallback_entry = find_entry(entries, str(fallback.get("mechanic_profile_id", "")), str(fallback.get("content_pack_id", "")))
    formal12_entry = find_entry(entries, "weapon_followup_v0_1", FORMAL12FAST_PACK_ID)
    report = {
        "current_release_has_sequence_template_id": bool(current.get("sequence_template_id")),
        "current_release_pack_identity_complete": bool(current.get("pack_identity")) and bool(current.get("build_variant")),
        "fallback_release_has_sequence_template_id": bool(fallback.get("sequence_template_id")),
        "pack_resolver_exists": True,
        "resolver_contains_current": bool(current_entry),
        "resolver_contains_fallback": bool(fallback_entry),
        "resolver_contains_formal12fast_candidate": bool(formal12_entry),
        "template_mechanic_pack_binding_valid": all(
            bool(entry and entry.get("resolver_entry_valid", False))
            for entry in [current_entry, fallback_entry, formal12_entry]
        ),
    }
    report["probe_pass"] = all(report.values())
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(markdown(report), encoding="utf-8")
    print("pack binding probe complete")
    return 0 if report["probe_pass"] else 1


def find_entry(entries: list[dict[str, Any]], profile_id: str, content_pack_id: str) -> dict[str, Any] | None:
    return next((
        entry for entry in entries
        if str(entry.get("mechanic_profile_id", "")) == profile_id
        and str(entry.get("content_pack_id", "")) == content_pack_id
    ), None)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def markdown(report: dict[str, Any]) -> str:
    return "# R5 Pack Binding Probe\n\n" + "\n".join(f"- {k}: `{v}`" for k, v in report.items()) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
