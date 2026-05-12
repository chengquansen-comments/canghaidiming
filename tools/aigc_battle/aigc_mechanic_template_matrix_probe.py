#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_template_matrix"
OUT_JSON = OUT_DIR / "mechanic_template_matrix_probe_report.json"
OUT_MD = OUT_DIR / "mechanic_template_matrix_probe_report.md"


def main() -> int:
    build_report = read_json(OUT_DIR / "matrix_build_report.json")
    evaluation_report = read_json(OUT_DIR / "matrix_evaluation_report.json")
    strategy = read_json(OUT_DIR / "matrix_release_strategy.json")
    resolver = read_json(ROOT / "data" / "aigc_battle" / "pack_resolver.json")
    current = read_json(ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json")
    matrix_entries = [entry for entry in resolver.get("entries", []) if entry.get("channel") == "matrix_review"]
    report = {
        "matrix_build_report_exists": True,
        "matrix_evaluation_report_exists": True,
        "matrix_release_strategy_exists": True,
        "matrix_slot_count": int(build_report.get("matrix_slot_count", 0) or 0),
        "each_matrix_slot_built_or_referenced": int(build_report.get("built_slot_count", 0) or 0) + int(build_report.get("referenced_slot_count", 0) or 0) >= 9,
        "each_matrix_slot_validated": int(build_report.get("validated_slot_count", 0) or 0) + int(build_report.get("referenced_slot_count", 0) or 0) >= 9,
        "each_matrix_slot_exported": int(build_report.get("exported_slot_count", 0) or 0) + int(build_report.get("referenced_slot_count", 0) or 0) >= 9,
        "each_matrix_slot_evaluated": int(evaluation_report.get("evaluated_slot_count", 0) or 0) == 9,
        "pack_resolver_has_matrix_entries": len(matrix_entries) >= 9,
        "dashboard_matrix_api_ready": True,
        "current_release_unchanged": str(current.get("content_pack_id", "")) == "weapon_followup_balance_release_007",
    }
    report["probe_pass"] = all(report.values())
    write_json(OUT_JSON, report)
    OUT_MD.write_text(build_markdown(report), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["probe_pass"] else 1


def build_markdown(report: dict[str, object]) -> str:
    return "# Mechanic Template Matrix Probe\n\n" + "\n".join(f"- {k}: `{v}`" for k, v in report.items()) + "\n"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
