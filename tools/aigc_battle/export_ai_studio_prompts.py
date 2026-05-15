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


PROMPT_DIR = ROOT / "data" / "aigc_battle" / "ai_studio" / "prompts"
FAST_REPORT = ROOT / "data" / "aigc_battle" / "generated" / "playable_hardening" / "fast_hardened_build_report.json"
BOSSRUSH_REPORT = ROOT / "data" / "aigc_battle" / "generated" / "playable_hardening" / "bossrush_hardened_build_report.json"
MATRIX_STRATEGY = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_template_matrix" / "matrix_release_strategy.json"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="export AI studio prompts")
    parser.add_argument("--default-r9-set", action="store_true")
    args = parser.parse_args(argv[1:])
    payload = export_default_set() if args.default_r9_set or True else export_default_set()
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


def export_default_set() -> dict[str, Any]:
    channels = release_lib.show_channels()
    current = channels.get("current_release", {})
    fast_report = try_read_json(FAST_REPORT) or {}
    bossrush_report = try_read_json(BOSSRUSH_REPORT) or {}
    matrix_strategy = try_read_json(MATRIX_STRATEGY) or {}
    PROMPT_DIR.mkdir(parents=True, exist_ok=True)

    prompts = [
        build_prompt(
            "standard_repair_prompt",
            "standard_repair",
            str(current.get("mechanic_profile_id", "weapon_followup_v0_1")),
            str(current.get("sequence_template_id", "formal_sequence_15_v1")),
            str(current.get("content_pack_id", "weapon_followup_balance_release_007")),
            "修正标准正式包的内容候选，但不能直接产出 runtime_manifest 或 active_profile。",
            "standard_run",
        ),
        build_prompt(
            "fast_repair_prompt",
            "fast_repair",
            "weapon_followup_v0_1",
            "formal_sequence_12_fast_v1",
            str(fast_report.get("actual_pack_id", "weapon_followup_v0_1__formal_sequence_12_fast_v1__hardened_013")),
            "聚焦 fast-run 平均回合数略高问题，优先降低拖长而不破坏 weapon_followup 可见性。",
            "fast_run",
        ),
        build_prompt(
            "bossrush_repair_prompt",
            "bossrush_repair",
            "weapon_followup_v0_1",
            "bossrush_9_v1",
            str(bossrush_report.get("actual_pack_id", "weapon_followup_v0_1__bossrush_9_v1__hardened_007")),
            "聚焦 bossrush 胜率过高与 too_long 略高问题，保持高压而非降成普通局。",
            "bossrush",
        ),
        build_prompt(
            "mechanic_showcase_prompt",
            "mechanic_showcase",
            "clue_pressure_v0_1",
            "bossrush_9_v1",
            str(
                (matrix_strategy.get("recommended_clue_pressure_template", {}) or {}).get(
                    "content_pack_id",
                    "clue_pressure_v0_1__bossrush_9_v1__matrix_001",
                )
                if isinstance(matrix_strategy.get("recommended_clue_pressure_template", {}), dict)
                else matrix_strategy.get("recommended_clue_pressure_template", "clue_pressure_v0_1__bossrush_9_v1__matrix_001")
            ),
            "为 clue_pressure / martial_realm_7_dual_weapon 准备机制展示型 candidates，只能输出 candidates JSONL。",
            "showcase",
        ),
    ]

    for item in prompts:
        (PROMPT_DIR / f"{item['prompt_id']}.md").write_text(item["markdown"], encoding="utf-8")
        write_json(PROMPT_DIR / f"{item['prompt_id']}.schema.json", candidate_schema(item["mechanic_profile_id"], item["sequence_template_id"]))

    manifest = {
        "generated_at": now_iso(),
        "prompt_count": len(prompts),
        "schema_count": len(prompts),
        "offline_mode_default": True,
        "online_llm_adapter_supported": False,
        "online_mode_requires_explicit_future_config": True,
        "llm_never_writes_runtime_manifest": True,
        "llm_never_writes_active_profile": True,
        "prompts": [
            {
                "prompt_id": item["prompt_id"],
                "prompt_type": item["prompt_type"],
                "mechanic_profile_id": item["mechanic_profile_id"],
                "sequence_template_id": item["sequence_template_id"],
                "source_pack_id": item["source_pack_id"],
                "recommended_release_mode": item["recommended_release_mode"],
                "markdown_path": to_relative(PROMPT_DIR / f"{item['prompt_id']}.md"),
                "schema_path": to_relative(PROMPT_DIR / f"{item['prompt_id']}.schema.json"),
            }
            for item in prompts
        ],
        "prompt_studio_ready": True,
    }
    write_json(PROMPT_DIR / "r9_prompt_manifest.json", manifest)
    return manifest


def build_prompt(
    prompt_id: str,
    prompt_type: str,
    mechanic_profile_id: str,
    sequence_template_id: str,
    source_pack_id: str,
    goal: str,
    recommended_release_mode: str,
) -> dict[str, Any]:
    markdown = "\n".join(
        [
            f"# {prompt_id}",
            "",
            f"- prompt_type: `{prompt_type}`",
            f"- mechanic_profile_id: `{mechanic_profile_id}`",
            f"- sequence_template_id: `{sequence_template_id}`",
            f"- source_pack_id: `{source_pack_id}`",
            f"- recommended_release_mode: `{recommended_release_mode}`",
            "",
            "输出要求：",
            "- 只能输出 candidates JSONL。",
            "- 不允许输出 runtime_manifest。",
            "- 不允许输出 active_profile。",
            "- 不允许输出 Godot 代码。",
            "- 不允许使用 unsupported effect。",
            "- 必须遵守 sequence_template + mechanic_profile + build_variant 契约。",
            "- 必须遵守武境 / 收式 / 双武器 / clue_pressure / weapon_followup 校验规则。",
            "",
            "生成目标：",
            f"- {goal}",
            "",
        ]
    ) + "\n"
    return {
        "prompt_id": prompt_id,
        "prompt_type": prompt_type,
        "mechanic_profile_id": mechanic_profile_id,
        "sequence_template_id": sequence_template_id,
        "source_pack_id": source_pack_id,
        "recommended_release_mode": recommended_release_mode,
        "markdown": markdown,
    }


def candidate_schema(mechanic_profile_id: str, sequence_template_id: str) -> dict[str, Any]:
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "AIGC Battle AI Studio Candidate JSONL line",
        "type": "object",
        "required": ["candidate_id", "candidate_type", "mechanic_profile_id", "sequence_template_id"],
        "properties": {
            "candidate_id": {"type": "string"},
            "candidate_type": {
                "type": "string",
                "enum": [
                    "card_candidate",
                    "deck_candidate",
                    "reward_candidate",
                    "battle_slot_candidate",
                    "sequence_adjustment_candidate",
                    "balance_adjustment_candidate",
                ],
            },
            "mechanic_profile_id": {"const": mechanic_profile_id},
            "sequence_template_id": {"const": sequence_template_id},
        },
        "additionalProperties": True,
    }


def try_read_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
