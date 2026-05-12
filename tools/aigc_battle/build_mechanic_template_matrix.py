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

from tools.aigc_battle import load_sequence_template as template_lib

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_template_matrix"
BUILD_JSON = OUT_DIR / "matrix_build_report.json"
BUILD_MD = OUT_DIR / "matrix_build_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"

MECHANICS = [
    "weapon_followup_v0_1",
    "clue_pressure_v0_1",
    "martial_realm_7_dual_weapon_v0_1",
]
TEMPLATES = [
    "formal_sequence_15_v1",
    "formal_sequence_12_fast_v1",
    "bossrush_9_v1",
]


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    report = build_matrix()
    write_json(BUILD_JSON, report)
    BUILD_MD.write_text(build_markdown(report), encoding="utf-8")
    print(f"built mechanic template matrix: slots={report['matrix_slot_count']} built={report['built_slot_count']} referenced={report['referenced_slot_count']}")
    ready = (
        report["matrix_mechanic_count"] == 3
        and report["matrix_template_count"] == 3
        and report["matrix_slot_count"] == 9
        and report["failed_slot_count"] == 0
        and report["validated_slot_count"] + report["referenced_slot_count"] >= 9
        and report["exported_slot_count"] + report["referenced_slot_count"] >= 9
        and report["current_release_unchanged"]
    )
    return 0 if ready else 1


def build_matrix() -> dict[str, Any]:
    current_release = read_json(CURRENT_RELEASE_PATH)
    current_pack_id = str(current_release.get("content_pack_id", ""))
    current_profile_id = str(current_release.get("mechanic_profile_id", ""))
    slots: list[dict[str, Any]] = []
    built_pack_ids: list[str] = []
    validated_pack_ids: list[str] = []
    exported_pack_ids: list[str] = []
    failed_slots: list[dict[str, Any]] = []
    referenced_slot_count = 0

    for mechanic_profile_id in MECHANICS:
        for sequence_template_id in TEMPLATES:
            if mechanic_profile_id == "weapon_followup_v0_1" and sequence_template_id == "formal_sequence_15_v1":
                referenced_slot_count += 1
                slots.append(
                    {
                        "mechanic_profile_id": mechanic_profile_id,
                        "sequence_template_id": sequence_template_id,
                        "build_variant": "matrix_reference_001",
                        "content_pack_id": current_pack_id,
                        "channel": "matrix_review",
                        "source": "current_release_reference",
                        "source_pack_id": current_pack_id,
                        "referenced": True,
                        "validated": True,
                        "exported": True,
                        "failed": False,
                        "total_encounter_count": int(current_release.get("total_encounter_count", 15) or 15),
                        "stage_counts": current_release.get("stage_counts", {}),
                        "runtime_primitives": ["weapon_followup"],
                    }
                )
                continue

            build_variant = "matrix_001"
            content_pack_id = f"{mechanic_profile_id}__{sequence_template_id}__{build_variant}"
            slot = {
                "mechanic_profile_id": mechanic_profile_id,
                "sequence_template_id": sequence_template_id,
                "build_variant": build_variant,
                "content_pack_id": content_pack_id,
                "channel": "matrix_review",
                "source": "matrix_build",
                "source_pack_id": "",
                "referenced": False,
                "validated": False,
                "exported": False,
                "failed": False,
            }
            try:
                run_step([
                    sys.executable,
                    str(ROOT / "tools" / "aigc_battle" / "build_content_for_profile.py"),
                    mechanic_profile_id,
                    "--sequence-template",
                    sequence_template_id,
                    "--build-variant",
                    build_variant,
                    "--pack-id",
                    content_pack_id,
                ])
                built_pack_ids.append(content_pack_id)
                run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "validate_content_pack.py"), mechanic_profile_id, "--pack", content_pack_id])
                validated_pack_ids.append(content_pack_id)
                slot["validated"] = True
                run_step([sys.executable, str(ROOT / "tools" / "aigc_battle" / "export_runtime_manifest.py"), mechanic_profile_id, "--pack", content_pack_id])
                exported_pack_ids.append(content_pack_id)
                slot["exported"] = True
                generated_dir = ROOT / "data" / "aigc_battle" / "generated" / mechanic_profile_id / "packs" / content_pack_id
                runtime_manifest = read_json(generated_dir / "runtime_manifest.json")
                slot["total_encounter_count"] = int(runtime_manifest.get("total_encounter_count", 0) or 0)
                slot["stage_counts"] = runtime_manifest.get("stage_counts", {})
                slot["runtime_primitives"] = list(runtime_manifest.get("runtime_primitives", []))
            except subprocess.CalledProcessError as exc:
                slot["failed"] = True
                failed_slots.append(
                    {
                        "mechanic_profile_id": mechanic_profile_id,
                        "sequence_template_id": sequence_template_id,
                        "content_pack_id": content_pack_id,
                        "returncode": exc.returncode,
                    }
                )
                slots.append(slot)
                break
            slots.append(slot)
        if failed_slots:
            break

    current_unchanged = (
        str(read_json(CURRENT_RELEASE_PATH).get("mechanic_profile_id", "")) == current_profile_id
        and str(read_json(CURRENT_RELEASE_PATH).get("content_pack_id", "")) == current_pack_id
    )
    report = {
        "generated_at": now_iso(),
        "matrix_mechanic_count": len(MECHANICS),
        "matrix_template_count": len(TEMPLATES),
        "matrix_slot_count": len(MECHANICS) * len(TEMPLATES),
        "built_slot_count": len(built_pack_ids),
        "referenced_slot_count": referenced_slot_count,
        "validated_slot_count": len(validated_pack_ids),
        "exported_slot_count": len(exported_pack_ids),
        "failed_slot_count": len(failed_slots),
        "matrix_pack_ids": [slot["content_pack_id"] for slot in slots],
        "failed_slots": failed_slots,
        "current_release_unchanged": current_unchanged,
        "matrix_build_ready": len(failed_slots) == 0 and current_unchanged,
        "matrix_slots": slots,
    }
    return report


def build_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Matrix Build Report",
        "",
        f"- matrix_mechanic_count: `{report.get('matrix_mechanic_count', 0)}`",
        f"- matrix_template_count: `{report.get('matrix_template_count', 0)}`",
        f"- matrix_slot_count: `{report.get('matrix_slot_count', 0)}`",
        f"- built_slot_count: `{report.get('built_slot_count', 0)}`",
        f"- referenced_slot_count: `{report.get('referenced_slot_count', 0)}`",
        f"- validated_slot_count: `{report.get('validated_slot_count', 0)}`",
        f"- exported_slot_count: `{report.get('exported_slot_count', 0)}`",
        f"- failed_slot_count: `{report.get('failed_slot_count', 0)}`",
    ]
    for slot in report.get("matrix_slots", []):
        lines.append(
            f"- {slot['mechanic_profile_id']} x {slot['sequence_template_id']} -> `{slot['content_pack_id']}` | "
            f"referenced={slot.get('referenced', False)} | validated={slot.get('validated', False)} | exported={slot.get('exported', False)}"
        )
    return "\n".join(lines) + "\n"


def run_step(cmd: list[str]) -> None:
    subprocess.run(cmd, cwd=ROOT, check=True)


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main())
