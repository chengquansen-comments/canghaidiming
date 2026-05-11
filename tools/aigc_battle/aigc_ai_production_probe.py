#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import switch_active_profile as switch_lib


PROFILE_ID = "weapon_followup_v0_1"
SOURCE_PACK_ID = "weapon_followup_v0_1_formal_sequence_pack_001"
REPORT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "ai_production"
LLM_PROFILE_DIR = ROOT / "data" / "aigc_battle" / "llm_candidates" / PROFILE_ID


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python3 tools/aigc_battle/aigc_ai_production_probe.py", file=sys.stderr)
        return 1
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    ai_pack_id = allocate_probe_pack_id()
    candidate_input_path = LLM_PROFILE_DIR / "probe_candidates.jsonl"
    write_jsonl(candidate_input_path, build_probe_candidates())

    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "export_llm_generation_prompt.py"), "--profile", PROFILE_ID, "--pack", SOURCE_PACK_ID])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "import_llm_production_candidates.py"), "--profile", PROFILE_ID, "--input", str(candidate_input_path)])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "diff_llm_candidates.py"), "--profile", PROFILE_ID, "--pack", SOURCE_PACK_ID])
    run([sys.executable, str(ROOT / "tools" / "aigc_battle" / "build_ai_content_pack.py"), "--profile", PROFILE_ID, "--pack-id", ai_pack_id])

    import_report = read_json(ROOT / "data" / "aigc_battle" / "generated" / "ai_production" / "import_reports" / f"{PROFILE_ID}__candidate_import_report.json")
    diff_report = read_json(ROOT / "data" / "aigc_battle" / "generated" / "ai_production" / "diff" / f"{PROFILE_ID}__candidate_diff.json")
    validation_report = read_json(switch_lib.resolve_generated_dir(PROFILE_ID, ai_pack_id) / "validation_report.json")
    pack_review = read_json(review_lib.pack_review_json_path(PROFILE_ID, ai_pack_id))
    safe_switch_ready = True
    try:
        switch_lib.validate_profile_ready(PROFILE_ID, ai_pack_id)
    except SystemExit:
        safe_switch_ready = False

    report = {
        "llm_prompt_export_ready": (ROOT / "data" / "aigc_battle" / "llm_prompts" / f"{PROFILE_ID}__{SOURCE_PACK_ID}__candidate_prompt.md").exists(),
        "llm_candidate_import_ready": import_report.get("accepted_candidate_count", 0) > 0,
        "invalid_llm_candidate_rejected": import_report.get("rejected_candidate_count", 0) > 0,
        "valid_llm_candidate_accepted": import_report.get("accepted_candidate_count", 0) > 0,
        "candidate_diff_ready": bool(diff_report.get("candidate_diff_ready", False)),
        "valid_llm_pack_generated": (switch_lib.resolve_generated_dir(PROFILE_ID, ai_pack_id) / "runtime_manifest.json").exists(),
        "ai_pack_validated": bool(validation_report.get("ready_for_runtime_export", False)),
        "ai_pack_exported": (switch_lib.resolve_generated_dir(PROFILE_ID, ai_pack_id) / "runtime_manifest.json").exists(),
        "review_workspace_shows_llm_source": bool(pack_review.get("llm_candidate_source", False)),
        "safe_switch_llm_pack_ready": safe_switch_ready,
        "probe_pass": False,
        "ai_pack_id": ai_pack_id,
    }
    report["probe_pass"] = all(bool(report[key]) for key in report if key not in {"probe_pass", "ai_pack_id"})
    json_path = REPORT_DIR / "aigc_ai_production_probe_report.json"
    md_path = REPORT_DIR / "aigc_ai_production_probe_report.md"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    md_path.write_text("\n".join([f"- {k}: {str(v).lower() if isinstance(v, bool) else v}" for k, v in report.items()]) + "\n", encoding="utf-8")
    print(f"wrote {json_path.relative_to(ROOT)}")
    return 0 if report["probe_pass"] else 1


def build_probe_candidates() -> list[dict[str, Any]]:
    return [
        {
            "candidate_id": "probe_card_valid_001",
            "candidate_type": "card_candidate",
            "mechanic_profile_id": PROFILE_ID,
            "target_sequence_id": "formal_sequence_mvp_v1",
            "source": "offline_llm_candidate",
            "content": {
                "card_id": "weapon_followup_probe_card_001",
                "name": "追击试锋",
                "card_type": "attack",
                "weapon_style": "spearman",
                "cost": 1,
                "effects": [{"type": "damage", "value": 4}, {"type": "gain_momentum", "value": 1}],
                "tags": ["followup", "probe"],
                "difficulty_tier": "mid",
                "power_score": 5,
                "required_wujing": 2,
                "closing_form_tier": 1,
                "runtime_effects": ["damage", "gain_momentum"],
                "followup_group": "probe_chain",
                "followup_trigger": "same_weapon_previous_card",
                "followup_bonus": {"bonus_momentum": 1},
                "followup_chain_role": "linker",
            },
        },
        {
            "candidate_id": "probe_deck_valid_001",
            "candidate_type": "deck_candidate",
            "mechanic_profile_id": PROFILE_ID,
            "target_sequence_id": "formal_sequence_mvp_v1",
            "source": "offline_llm_candidate",
            "content": {
                "deck_id": "weapon_followup_v0_1_deck_001",
                "encounter_tier": "early",
                "enemy_role": "spearman",
                "card_refs": ["weapon_followup_probe_card_001", "weapon_followup_v0_1_spearman_early_strike", "weapon_followup_v0_1_spearman_early_guard", "weapon_followup_v0_1_spearman_early_pressure", "weapon_followup_v0_1_spearman_early_focus", "weapon_followup_v0_1_spearman_early_finisher"],
                "deck_power_score": 25,
                "target_power_min": 20,
                "target_power_max": 30,
                "followup_chain_count": 3,
                "followup_density": 0.5,
                "followup_groups": ["probe_chain"],
            },
        },
        {
            "candidate_id": "probe_reward_valid_001",
            "candidate_type": "reward_candidate",
            "mechanic_profile_id": PROFILE_ID,
            "target_sequence_id": "formal_sequence_mvp_v1",
            "source": "offline_llm_candidate",
            "content": {
                "reward_plan_id": "weapon_followup_v0_1_reward_001",
                "reward_type": "card_pick",
                "reward_tier": "basic",
                "reward_items": [{"type": "card_pick", "count": 1}],
            },
        },
        {
            "candidate_id": "probe_slot_valid_001",
            "candidate_type": "battle_slot_candidate",
            "mechanic_profile_id": PROFILE_ID,
            "target_sequence_id": "formal_sequence_mvp_v1",
            "source": "offline_llm_candidate",
            "content": {
                "formal_encounter_id": "enc_beach_ambush",
                "generated_battle_slot_id": "weapon_followup_v0_1_slot_001",
                "deck_id": "weapon_followup_v0_1_deck_001",
                "reward_plan_id": "weapon_followup_v0_1_reward_001",
                "encounter_tier": "early",
                "player_wujing_cap": 1,
                "target_power_min": 20,
                "target_power_max": 30,
                "runtime_primitives": ["weapon_followup"],
            },
        },
        {
            "candidate_id": "probe_card_invalid_effect",
            "candidate_type": "card_candidate",
            "mechanic_profile_id": PROFILE_ID,
            "target_sequence_id": "formal_sequence_mvp_v1",
            "source": "offline_llm_candidate",
            "content": {
                "card_id": "weapon_followup_probe_card_bad_effect",
                "name": "非法异常牌",
                "card_type": "attack",
                "weapon_style": "spearman",
                "cost": 1,
                "effects": [{"type": "summon_pet", "value": 1}],
                "tags": ["invalid"],
                "difficulty_tier": "mid",
                "power_score": 4,
                "required_wujing": 1,
                "closing_form_tier": 1,
                "runtime_effects": ["summon_pet"],
            },
        },
        {
            "candidate_id": "probe_card_invalid_realm",
            "candidate_type": "card_candidate",
            "mechanic_profile_id": PROFILE_ID,
            "target_sequence_id": "formal_sequence_mvp_v1",
            "source": "offline_llm_candidate",
            "content": {
                "card_id": "weapon_followup_probe_card_bad_realm",
                "name": "越境试探",
                "card_type": "attack",
                "weapon_style": "spearman",
                "cost": 1,
                "effects": [{"type": "damage", "value": 6}],
                "tags": ["invalid"],
                "difficulty_tier": "late",
                "power_score": 7,
                "required_wujing": -1,
                "closing_form_tier": 1,
                "runtime_effects": ["damage"],
            },
        },
        {
            "candidate_id": "probe_card_invalid_followup",
            "candidate_type": "card_candidate",
            "mechanic_profile_id": PROFILE_ID,
            "target_sequence_id": "formal_sequence_mvp_v1",
            "source": "offline_llm_candidate",
            "content": {
                "card_id": "weapon_followup_probe_card_bad_followup",
                "name": "错触发追击",
                "card_type": "attack",
                "weapon_style": "spearman",
                "cost": 1,
                "effects": [{"type": "damage", "value": 4}],
                "tags": ["invalid"],
                "difficulty_tier": "mid",
                "power_score": 5,
                "required_wujing": 1,
                "closing_form_tier": 1,
                "runtime_effects": ["damage"],
                "followup_trigger": "bad_trigger",
                "followup_bonus": {"bonus_momentum": 9},
            },
        },
    ]


def run(cmd: list[str]) -> None:
    completed = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if completed.returncode != 0:
        raise SystemExit((completed.stderr or completed.stdout or "command failed").strip())


def write_jsonl(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(row, ensure_ascii=False) for row in rows) + "\n", encoding="utf-8")


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def allocate_probe_pack_id() -> str:
    packs_dir = switch_lib.resolve_generated_dir(PROFILE_ID) / "packs"
    packs_dir.mkdir(parents=True, exist_ok=True)
    prefix = "weapon_followup_ai_candidate_pack_probe_"
    existing = {path.name for path in packs_dir.iterdir() if path.is_dir()}
    index = 1
    while True:
        candidate = f"{prefix}{index:03d}"
        if candidate not in existing:
            return candidate
        index += 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
