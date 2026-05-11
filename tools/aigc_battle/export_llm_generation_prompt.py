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

from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import switch_active_profile as switch_lib


PROMPT_DIR = ROOT / "data" / "aigc_battle" / "llm_prompts"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="export offline llm generation prompt")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--pack", required=True)
    args = parser.parse_args(argv[1:])
    profile_id = args.profile
    content_pack_id = args.pack
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(content_pack_id, "content_pack_id")

    mechanic_profile = read_json(ROOT / "data" / "aigc_battle" / "mechanics" / profile_id / "mechanic_profile.json")
    content_recipe = read_json(ROOT / "data" / "aigc_battle" / "mechanics" / profile_id / "content_recipe.json")
    pack_review_path = review_lib.pack_review_json_path(profile_id, content_pack_id)
    pack_review = read_json(pack_review_path) if pack_review_path.exists() else {}
    generated_dir = switch_lib.resolve_generated_dir(profile_id, content_pack_id if content_pack_id != content_recipe.get("content_pack_id") else None)
    telemetry_snapshot_path = generated_dir / "real_telemetry_snapshot.json"
    telemetry_snapshot = read_json(telemetry_snapshot_path) if telemetry_snapshot_path.exists() else {}

    schema = build_candidate_schema()
    prompt_context = {
        "profile_id": profile_id,
        "content_pack_id": content_pack_id,
        "generated_at": now_iso(),
        "source_pack_review_path": to_relative(pack_review_path) if pack_review_path.exists() else "",
        "source_real_telemetry_snapshot_path": to_relative(telemetry_snapshot_path) if telemetry_snapshot_path.exists() else "",
        "risk_summary": pack_review.get("risk_summary", {}),
        "candidate_schema_path": to_relative(prompt_schema_path(profile_id, content_pack_id)),
    }
    prompt_md = build_prompt_markdown(mechanic_profile, content_recipe, pack_review, telemetry_snapshot, prompt_context)

    prompt_path = prompt_md_path(profile_id, content_pack_id)
    schema_path = prompt_schema_path(profile_id, content_pack_id)
    context_path = prompt_context_path(profile_id, content_pack_id)
    PROMPT_DIR.mkdir(parents=True, exist_ok=True)
    prompt_path.write_text(prompt_md, encoding="utf-8")
    schema_path.write_text(json.dumps(schema, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    context_path.write_text(json.dumps(prompt_context, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "ok": True,
        "prompt_path": to_relative(prompt_path),
        "schema_path": to_relative(schema_path),
        "context_path": to_relative(context_path),
    }, ensure_ascii=False, indent=2))
    return 0


def build_prompt_markdown(
    mechanic_profile: dict[str, Any],
    content_recipe: dict[str, Any],
    pack_review: dict[str, Any],
    telemetry_snapshot: dict[str, Any],
    prompt_context: dict[str, Any],
) -> str:
    risk_summary = pack_review.get("risk_summary", {})
    top_risks = risk_summary.get("top_risks", [])[:10]
    rebuild_recommendations = telemetry_snapshot.get("rebuild_recommendations", [])[:10]
    runtime_primitives = mechanic_profile.get("runtime_primitives", [])
    followup_constraints = mechanic_profile.get("runtime_primitive_constraints", {}).get("weapon_followup", {})
    balance_policy = content_recipe.get("balance_policy", {})
    progression_policy = content_recipe.get("player_progression_policy", {})
    lines = [
        f"# AIGC Battle 候选生成提示词：{mechanic_profile.get('mechanic_profile_id', '')} / {content_recipe.get('content_pack_id', '')}",
        "",
        "## 1. profile 摘要",
        f"- mechanic_profile_id: `{mechanic_profile.get('mechanic_profile_id', '')}`",
        f"- content_pack_id: `{content_recipe.get('content_pack_id', '')}`",
        f"- target_sequence_id: `{content_recipe.get('target_sequence_id', '')}`",
        f"- replacement_mode: `{content_recipe.get('replacement_mode', '')}`",
        f"- runtime_primitives: `{', '.join(runtime_primitives) or '-'}`",
        f"- allowed_runtime_effects: `{', '.join(mechanic_profile.get('allowed_runtime_effects', [])) or '-'}`",
        f"- weapon_styles: `{', '.join(mechanic_profile.get('weapon_styles', [])) or '-'}`",
        f"- card_eligibility_rules: `{json.dumps(mechanic_profile.get('card_eligibility_rules', {}), ensure_ascii=False)}`",
        f"- player_progression_policy: `{json.dumps(progression_policy, ensure_ascii=False)}`",
        f"- balance_policy: `{json.dumps(balance_policy, ensure_ascii=False)}`",
        "",
        "## 2. 生成边界",
        "- 只能生成 candidates。",
        "- 不允许生成 runtime_manifest。",
        "- 不允许生成 active_profile。",
        "- 不允许生成 Godot 脚本。",
        "- 不允许使用 unsupported effect。",
        "- 不允许突破 required_wujing / closing_form_tier。",
        "- 不允许缺 required fields。",
        "- 不允许单场不覆盖。",
        "",
        "## 3. 输出格式",
        "- 输出格式必须是 JSONL。",
        "- 每行一个 candidate。",
        "- candidate_type 只允许：`card_candidate` / `deck_candidate` / `reward_candidate` / `battle_slot_candidate`。",
        "- 每行必须包含：`candidate_id` / `candidate_type` / `mechanic_profile_id` / `target_sequence_id` / `source` / `content`。",
        "",
        "## 4. weapon_followup 约束",
    ]
    if "weapon_followup" in runtime_primitives:
        lines.extend([
            "- 必须包含 followup_group / followup_trigger / followup_bonus / followup_chain_role / weapon_style。",
            f"- followup constraints: `{json.dumps(followup_constraints, ensure_ascii=False)}`",
            "- followup_trigger 只能使用 same_weapon_previous_card / specific_tag_previous_card / stance_gain_previous_card。",
            "- followup_chain_role 只能使用 opener / linker / finisher / standalone。",
        ])
    else:
        lines.append("- 当前 profile 不声明 weapon_followup，可忽略该组字段。")
    lines.extend([
        "",
        "## 5. 风险修复上下文",
        f"- top_risks: `{json.dumps(top_risks, ensure_ascii=False)}`",
        f"- rebuild_recommendations: `{json.dumps(rebuild_recommendations, ensure_ascii=False)}`",
        f"- too_hard_candidates: `{json.dumps(telemetry_snapshot.get('too_hard_candidates', []), ensure_ascii=False)}`",
        f"- too_easy_candidates: `{json.dumps(telemetry_snapshot.get('too_easy_candidates', []), ensure_ascii=False)}`",
        f"- underused_card_candidates: `{json.dumps(telemetry_snapshot.get('underused_card_candidates', []), ensure_ascii=False)}`",
        f"- overused_card_candidates: `{json.dumps(telemetry_snapshot.get('overused_card_candidates', []), ensure_ascii=False)}`",
        f"- reward_mismatch_candidates: `{json.dumps(telemetry_snapshot.get('reward_mismatch_candidates', []), ensure_ascii=False)}`",
        "",
        "## 6. prompt_context",
        f"```json\n{json.dumps(prompt_context, ensure_ascii=False, indent=2)}\n```",
        "",
        "## 7. 输出提醒",
        "- 默认 offline mode，只导出候选内容，不调用在线 LLM。",
        "- source 字段请写明来源，例如 `offline_llm_candidate` / `designer_candidate`。",
        "- 所有候选会进入 import / validate / diff / build / export / review / release gate；不合规会被拒绝。",
    ])
    return "\n".join(lines) + "\n"


def build_candidate_schema() -> dict[str, Any]:
    return {
        "type": "object",
        "required": ["candidate_id", "candidate_type", "mechanic_profile_id", "target_sequence_id", "source", "content"],
        "properties": {
            "candidate_id": {"type": "string"},
            "candidate_type": {"type": "string", "enum": ["card_candidate", "deck_candidate", "reward_candidate", "battle_slot_candidate"]},
            "mechanic_profile_id": {"type": "string"},
            "target_sequence_id": {"type": "string"},
            "source": {"type": "string"},
            "content": {
                "type": "object",
                "properties": {
                    "followup_group": {"type": "string"},
                    "followup_trigger": {"type": "string"},
                    "followup_bonus": {"type": "object"},
                    "followup_chain_role": {"type": "string"},
                },
            },
        },
    }


def prompt_md_path(profile_id: str, content_pack_id: str) -> Path:
    return PROMPT_DIR / f"{profile_id}__{content_pack_id}__candidate_prompt.md"


def prompt_schema_path(profile_id: str, content_pack_id: str) -> Path:
    return PROMPT_DIR / f"{profile_id}__{content_pack_id}__candidate_schema.json"


def prompt_context_path(profile_id: str, content_pack_id: str) -> Path:
    return PROMPT_DIR / f"{profile_id}__{content_pack_id}__prompt_context.json"


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
