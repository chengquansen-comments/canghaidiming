#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_aigc_content_index as index_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import switch_active_profile as switch_lib

GENERATED_ROOT = ROOT / 'data' / 'aigc_battle' / 'generated'
DETAILS_DIR = GENERATED_ROOT / 'details'
MECHANICS_DIR = ROOT / 'data' / 'aigc_battle' / 'mechanics'
PROFILE_DIFF_PATH = GENERATED_ROOT / 'profile_diff_report.json'
EVALUATION_REPORTS_DIR = GENERATED_ROOT / 'evaluation' / 'reports'
EVALUATION_SNAPSHOT_DIR = ROOT / 'data' / 'aigc_battle' / 'evaluation' / 'snapshots'
REBUILD_RECOMMEND_DIR = ROOT / 'data' / 'aigc_battle' / 'evaluation' / 'rebuild_recommendations'


def main() -> int:
    index_payload = index_lib.build_index()
    DETAILS_DIR.mkdir(parents=True, exist_ok=True)
    profile_count = 0
    pack_count = 0
    for profile_entry in index_payload.get('profiles', []):
        profile_id = str(profile_entry['mechanic_profile_id'])
        build_profile_detail(profile_entry)
        profile_count += 1
        for pack_entry in profile_entry.get('content_packs', []):
            build_pack_detail(profile_id, pack_entry)
            pack_count += 1
    print(f'built aigc detail views: profiles={profile_count} packs={pack_count}')
    return 0


def build_profile_detail(profile_entry: dict[str, Any]) -> None:
    profile_id = str(profile_entry['mechanic_profile_id'])
    mechanic_profile = try_read_json(MECHANICS_DIR / profile_id / 'mechanic_profile.json') or {}
    content_recipe = try_read_json(MECHANICS_DIR / profile_id / 'content_recipe.json') or {}
    profile_diff = try_read_json(PROFILE_DIFF_PATH) or {}
    missing_fields: list[str] = []
    for field in ['resources', 'card_types', 'weapon_styles', 'allowed_runtime_effects', 'card_constraints', 'deck_constraints', 'power_model']:
        if field not in mechanic_profile:
            missing_fields.append(field)
    for field in ['target_sequence_id', 'replacement_mode', 'content_recipe_id']:
        if field not in content_recipe:
            missing_fields.append(field)
    validation_gate_summary = {
        'ready_packs': sum(1 for pack in profile_entry.get('content_packs', []) if pack.get('ready_for_runtime_export')),
        'total_packs': len(profile_entry.get('content_packs', [])),
        'active_pack_id': next((pack['content_pack_id'] for pack in profile_entry.get('content_packs', []) if pack.get('is_active_pack')), ''),
    }
    detail = {
        'mechanic_profile_id': profile_id,
        'display_name': mechanic_profile.get('display_name', ''),
        'version': mechanic_profile.get('version', ''),
        'content_pack_count': len(profile_entry.get('content_packs', [])),
        'active_pack_id': validation_gate_summary['active_pack_id'],
        'resources': mechanic_profile.get('resources', []),
        'card_types': mechanic_profile.get('card_types', []),
        'weapon_styles': mechanic_profile.get('weapon_styles', []),
        'allowed_design_effects': mechanic_profile.get('allowed_design_effects', []),
        'allowed_runtime_effects': mechanic_profile.get('allowed_runtime_effects', []),
        'runtime_primitives': mechanic_profile.get('runtime_primitives', []),
        'runtime_primitive_constraints': mechanic_profile.get('runtime_primitive_constraints', {}),
        'card_constraints': mechanic_profile.get('card_constraints', {}),
        'deck_constraints': mechanic_profile.get('deck_constraints', {}),
        'power_model': mechanic_profile.get('power_model', {}),
        'card_eligibility_rules': mechanic_profile.get('card_eligibility_rules', {}),
        'player_progression_policy': content_recipe.get('player_progression_policy', {}),
        'balance_policy': content_recipe.get('balance_policy', {}),
        'reward_generation_policy': content_recipe.get('reward_generation_policy', {}),
        'runtime_primitive_policy': content_recipe.get('runtime_primitive_policy', {}),
        'candidate_import_policy': content_recipe.get('candidate_import', {}),
        'target_sequence_id': content_recipe.get('target_sequence_id', ''),
        'replacement_mode': content_recipe.get('replacement_mode', ''),
        'content_recipe_id': content_recipe.get('content_recipe_id', ''),
        'validation_gate_summary': validation_gate_summary,
        'profile_pack_list': [
            {
                'content_pack_id': pack.get('content_pack_id', ''),
                'pack_storage_mode': pack.get('pack_storage_mode', ''),
                'is_active_pack': pack.get('is_active_pack', False),
                'ready_for_runtime_export': pack.get('ready_for_runtime_export', False),
                'sequence_balance_pass': pack.get('sequence_balance_pass', False),
                'runtime_primitives': pack.get('runtime_primitives', []),
            }
            for pack in profile_entry.get('content_packs', [])
        ],
        'profile_diff_summary': profile_diff if profile_diff.get('from_profile_id') == profile_id or profile_diff.get('to_profile_id') == profile_id else {},
        'missing_fields': missing_fields,
    }
    json_path = DETAILS_DIR / f'profile_{profile_id}.json'
    md_path = DETAILS_DIR / f'profile_{profile_id}.md'
    write_json(json_path, detail)
    md_path.write_text(build_profile_markdown(detail), encoding='utf-8')


def build_pack_detail(profile_id: str, pack_entry: dict[str, Any]) -> None:
    content_pack_id = str(pack_entry['content_pack_id'])
    pack_id = content_pack_id if pack_entry.get('pack_storage_mode') == 'profile_pack_dir' else None
    generated_dir = switch_lib.resolve_generated_dir(profile_id, pack_id)
    runtime_manifest = try_read_json(generated_dir / 'runtime_manifest.json') or {}
    validation_report = try_read_json(generated_dir / 'validation_report.json') or {}
    inventory = try_read_json(generated_dir / 'formal_sequence_inventory.generated.json') or []
    mapping = try_read_json(generated_dir / 'formal_sequence_mapping.generated.json') or []
    battle_slots = try_read_json(generated_dir / 'battle_slot_bindings.generated.json') or runtime_manifest.get('battle_slots', [])
    decks = try_read_json(generated_dir / 'enemy_deck_pool.generated.json') or runtime_manifest.get('enemy_decks', [])
    cards = try_read_json(generated_dir / 'card_pool.generated.json') or runtime_manifest.get('cards', [])
    rewards = try_read_json(generated_dir / 'rewards.generated.json') or runtime_manifest.get('rewards', [])
    balance_summary = try_read_json(generated_dir / 'sequence_balance_summary.json') or {}
    telemetry_probe = try_read_json(generated_dir / 'telemetry_probe_report.json') or {}
    snapshot = try_read_json(generated_dir / 'sequence_balance_snapshot.json') or {}
    primitive_probe = try_read_json(generated_dir / 'runtime_primitive_probe_report.json') or {}
    rebuild_probe = try_read_json(generated_dir / 'rebuild_from_snapshot_probe_report.json') or {}
    content_pack_summary = try_read_json(generated_dir / 'content_pack_summary.json') or {}
    snapshot_summary = try_read_json(generated_dir / 'snapshot_summary.json') or {}
    evaluation_report = try_read_json(EVALUATION_REPORTS_DIR / f'{profile_id}__{content_pack_id}__evaluation_report.json') or {}
    evaluation_snapshot = try_read_json(EVALUATION_SNAPSHOT_DIR / f'{profile_id}__{content_pack_id}__evaluation_snapshot.json') or {}
    rebuild_recommendations = try_read_json(REBUILD_RECOMMEND_DIR / f'{profile_id}__{content_pack_id}__rebuild_recommendations.json') or {}
    release_channels = release_lib.show_channels()
    current_release = release_channels.get('current_release', {})
    candidate_release = release_channels.get('candidate_release', {})
    fallback_release = release_channels.get('fallback_release', {})

    card_index = {str(card.get('card_id', '')): card for card in cards}
    deck_index = {str(deck.get('deck_id', '')): deck for deck in decks}
    slot_index = {str(slot.get('battle_slot_id', '')): slot for slot in battle_slots}
    reward_index = {str(reward.get('reward_plan_id', '')): reward for reward in rewards}
    inventory_by_encounter = {str(item.get('formal_encounter_id', '')): item for item in inventory}

    card_used_by_decks: dict[str, list[str]] = defaultdict(list)
    card_used_by_slots: dict[str, list[str]] = defaultdict(list)
    orphan_cards: list[dict[str, Any]] = []

    for deck in decks:
        deck_id = str(deck.get('deck_id', ''))
        for card_id in deck.get('card_ids', []):
            card_id = str(card_id)
            if card_id not in card_index:
                orphan_cards.append({'deck_id': deck_id, 'card_id': card_id})
                continue
            card_used_by_decks[card_id].append(deck_id)
    for slot in battle_slots:
        slot_id = str(slot.get('battle_slot_id', ''))
        deck = deck_index.get(str(slot.get('deck_id', '')))
        if not deck:
            continue
        for card_id in deck.get('card_ids', []):
            card_id = str(card_id)
            if card_id in card_index:
                card_used_by_slots[card_id].append(slot_id)

    effect_type_counts = Counter()
    weapon_style_counts = Counter()
    card_type_counts = Counter()
    difficulty_tier_counts = Counter()
    realm_requirement_counts = Counter()
    power_scores: list[float] = []
    card_pool_detail: list[dict[str, Any]] = []
    card_usage_index: list[dict[str, Any]] = []

    for card in cards:
        card_id = str(card.get('card_id', ''))
        used_decks = sorted(set(card_used_by_decks.get(card_id, [])))
        used_slots = sorted(set(card_used_by_slots.get(card_id, [])))
        usage_count = len(used_decks)
        power = float(card.get('power_score', 0) or 0)
        power_scores.append(power)
        weapon_style_counts[str(card.get('weapon_style', 'unknown'))] += 1
        card_type_counts[str(card.get('card_type', 'unknown'))] += 1
        difficulty_tier_counts[str(card.get('difficulty_tier', 'unknown'))] += 1
        realm_requirement_counts[f"w{card.get('required_wujing', '?')}_c{card.get('closing_form_tier', '?')}"] += 1
        for effect in card.get('effects', []):
            effect_type_counts[str(effect.get('type', 'unknown'))] += 1
        realm_eligibility_global_valid = True
        for slot_id in used_slots:
            slot = slot_index.get(slot_id, {})
            player_cap = int(slot.get('player_wujing_cap', 0) or 0)
            required = card.get('required_wujing')
            closing = card.get('closing_form_tier')
            if required is not None and int(required) > player_cap:
                realm_eligibility_global_valid = False
            if closing is not None and int(closing) > player_cap:
                realm_eligibility_global_valid = False
        card_detail = {
            'card_id': card_id,
            'name': card.get('name', ''),
            'card_type': card.get('card_type', ''),
            'weapon_style': card.get('weapon_style', ''),
            'cost': card.get('cost'),
            'effects': card.get('effects', []),
            'tags': card.get('tags', []),
            'difficulty_tier': card.get('difficulty_tier', ''),
            'power_score': power,
            'required_wujing': card.get('required_wujing'),
            'closing_form_tier': card.get('closing_form_tier'),
            'used_in_deck_ids': used_decks,
            'used_in_battle_slot_ids': used_slots,
            'usage_count': usage_count,
            'realm_eligibility_global_valid': realm_eligibility_global_valid,
        }
        card_pool_detail.append(card_detail)
        card_usage_index.append({
            'card_id': card_id,
            'used_by_decks': used_decks,
            'used_by_battle_slots': used_slots,
            'usage_count': usage_count,
        })

    used_card_ids = {item['card_id'] for item in card_pool_detail if item['usage_count'] > 0}
    unused_cards = [item['card_id'] for item in card_pool_detail if item['usage_count'] == 0]
    most_used_card_ids = [item['card_id'] for item in sorted(card_pool_detail, key=lambda item: (-item['usage_count'], item['card_id']))[:5] if item['usage_count'] > 0]
    high_power_card_ids = [item['card_id'] for item in sorted(card_pool_detail, key=lambda item: (-item['power_score'], item['card_id']))[:5]]
    technique_card_count = sum(1 for item in card_pool_detail if item['card_type'] == 'technique' or {'technique', 'closing_form', '招式', '收式'} & set(str(tag) for tag in item['tags']))
    generic_card_count = sum(1 for item in card_pool_detail if str(item['weapon_style']) == 'generic')

    sequence_detail = []
    for mapping_item in sorted(mapping, key=lambda item: int(item.get('sequence_position', 0) or 0)):
        formal_encounter_id = str(mapping_item.get('formal_encounter_id', ''))
        slot = slot_index.get(str(mapping_item.get('generated_battle_slot_id', '')), {})
        deck = deck_index.get(str(mapping_item.get('generated_deck_id', '')), {})
        reward = reward_index.get(str(mapping_item.get('reward_plan_id', '')), {})
        inventory_item = inventory_by_encounter.get(formal_encounter_id, {})
        card_summaries = []
        for card_id in deck.get('card_ids', []):
            card = card_index.get(str(card_id), {})
            player_cap = int(slot.get('player_wujing_cap', 0) or 0)
            required = int(card.get('required_wujing', 0) or 0) if card else 0
            closing = int(card.get('closing_form_tier', 0) or 0) if card else 0
            card_summaries.append({
                'card_id': str(card.get('card_id', card_id)),
                'name': card.get('name', ''),
                'card_type': card.get('card_type', ''),
                'weapon_style': card.get('weapon_style', ''),
                'cost': card.get('cost'),
                'effects': card.get('effects', []),
                'tags': card.get('tags', []),
                'difficulty_tier': card.get('difficulty_tier', ''),
                'power_score': card.get('power_score'),
                'required_wujing': card.get('required_wujing'),
                'closing_form_tier': card.get('closing_form_tier'),
                'realm_eligible_for_slot': required <= player_cap and closing <= player_cap,
            })
        sequence_detail.append({
            'sequence_position': mapping_item.get('sequence_position'),
            'formal_encounter_id': formal_encounter_id,
            'formal_battle_id': mapping_item.get('formal_battle_id', ''),
            'node_id': inventory_item.get('node_id', ''),
            'node_type': inventory_item.get('node_type', ''),
            'encounter_tier': mapping_item.get('encounter_tier', slot.get('encounter_tier', '')),
            'encounter_kind': mapping_item.get('encounter_kind', slot.get('encounter_kind', '')),
            'generated_battle_slot_id': mapping_item.get('generated_battle_slot_id', ''),
            'generated_deck_id': mapping_item.get('generated_deck_id', ''),
            'reward_plan_id': mapping_item.get('reward_plan_id', ''),
            'player_wujing_cap': mapping_item.get('player_wujing_cap', slot.get('player_wujing_cap')),
            'target_power_min': mapping_item.get('target_power_min', slot.get('target_power_min')),
            'target_power_max': mapping_item.get('target_power_max', slot.get('target_power_max')),
            'deck_power_score': deck.get('deck_power_score'),
            'power_range_pass': deck.get('power_range_pass'),
            'reward_tier': mapping_item.get('reward_tier', slot.get('reward_tier', reward.get('reward_tier', ''))),
            'runtime_primitives': slot.get('runtime_primitives', []),
            'opening_pressure': slot.get('opening_pressure'),
            'deck_summary': {
                'deck_id': deck.get('deck_id', ''),
                'enemy_role': deck.get('enemy_role', ''),
                'difficulty_tier': deck.get('difficulty_tier', ''),
                'deck_power_score': deck.get('deck_power_score'),
                'card_count': len(deck.get('card_ids', [])),
                'tags': deck.get('tags', []),
                'player_wujing_cap': deck.get('player_wujing_cap'),
                'realm_eligibility_checked': deck.get('realm_eligibility_checked'),
                'invalid_realm_card_count': deck.get('invalid_realm_card_count'),
            },
            'reward_summary': {
                'reward_plan_id': reward.get('reward_plan_id', ''),
                'reward_type': reward.get('reward_type', ''),
                'reward_tier': reward.get('reward_tier', ''),
                'reward_items': reward.get('reward_items', []),
            },
            'card_summaries': card_summaries,
        })

    missing_reports = []
    for name in ['telemetry_probe_report.json', 'sequence_balance_snapshot.json', 'runtime_primitive_probe_report.json', 'rebuild_from_snapshot_probe_report.json']:
        if not (generated_dir / name).exists():
            missing_reports.append(name)

    detail = {
        'mechanic_profile_id': profile_id,
        'content_pack_id': content_pack_id,
        'pack_storage_mode': pack_entry.get('pack_storage_mode', ''),
        'runtime_manifest_path': pack_entry.get('runtime_manifest_path', ''),
        'is_active_pack': pack_entry.get('is_active_pack', False),
        'release_channel_membership': {
            'is_current_release': profile_id == str(current_release.get('mechanic_profile_id', '')) and content_pack_id == str(current_release.get('content_pack_id', '')),
            'is_candidate_release': profile_id == str(candidate_release.get('mechanic_profile_id', '')) and content_pack_id == str(candidate_release.get('content_pack_id', '')),
            'is_fallback_release': profile_id == str(fallback_release.get('mechanic_profile_id', '')) and content_pack_id == str(fallback_release.get('content_pack_id', '')),
            'current_release_smoke_test_status': str(current_release.get('smoke_test_status', '')) if profile_id == str(current_release.get('mechanic_profile_id', '')) and content_pack_id == str(current_release.get('content_pack_id', '')) else '',
            'current_release_last_smoke_report_path': str(current_release.get('last_smoke_report_path', '')) if profile_id == str(current_release.get('mechanic_profile_id', '')) and content_pack_id == str(current_release.get('content_pack_id', '')) else '',
        },
        'target_sequence_id': runtime_manifest.get('target_sequence_id', ''),
        'replacement_mode': runtime_manifest.get('replacement_mode', ''),
        'formal_encounter_total_count': len(sequence_detail),
        'card_count': len(cards),
        'deck_count': len(decks),
        'battle_slot_count': len(battle_slots),
        'reward_count': len(rewards),
        'validation_summary': {
            'ready_for_runtime_export': validation_report.get('ready_for_runtime_export'),
            'full_sequence_coverage_complete': validation_report.get('full_sequence_coverage_complete'),
            'runtime_export_allowed': validation_report.get('runtime_export_allowed'),
            'sequence_balance_pass': validation_report.get('sequence_balance_pass'),
            'deck_card_realm_eligibility_valid': validation_report.get('deck_card_realm_eligibility_valid'),
            'no_card_above_player_wujing_in_deck': validation_report.get('no_card_above_player_wujing_in_deck'),
            'invalid_realm_card_count': validation_report.get('invalid_realm_card_count'),
            'missing_realm_metadata_count': validation_report.get('missing_realm_metadata_count'),
        },
        'balance_summary': balance_summary,
        'telemetry_summary': telemetry_probe or {'telemetry_event_count': snapshot.get('telemetry_event_count', 0)},
        'snapshot_summary': snapshot or snapshot_summary,
        'runtime_primitive_summary': primitive_probe or runtime_manifest.get('runtime_primitive_summary', {}),
        'evaluation_summary': evaluation_snapshot or evaluation_report,
        'rebuild_recommendation_summary': rebuild_recommendations,
        'ai_source_trace': {
            'llm_candidate_source': bool(content_pack_summary.get('llm_candidate_source', False)),
            'accepted_candidate_count': int(content_pack_summary.get('accepted_candidate_count', 0)),
            'rejected_candidate_count': int(content_pack_summary.get('rejected_candidate_count', 0)),
            'deterministic_fill_used': bool(content_pack_summary.get('deterministic_fill_used', False)),
            'candidate_import_report_path': str(content_pack_summary.get('candidate_import_report_path', '')),
            'candidate_diff_report_path': str(content_pack_summary.get('candidate_diff_report_path', '')),
            'built_from_llm_candidates': bool(content_pack_summary.get('built_from_llm_candidates', False)),
        },
        'card_pool_summary': {
            'card_count': len(cards),
            'used_card_count': len(used_card_ids),
            'unused_card_count': len(unused_cards),
            'technique_card_count': technique_card_count,
            'generic_card_count': generic_card_count,
            'weapon_style_counts': dict(weapon_style_counts),
            'card_type_counts': dict(card_type_counts),
            'difficulty_tier_counts': dict(difficulty_tier_counts),
            'realm_requirement_counts': dict(realm_requirement_counts),
            'effect_type_counts': dict(effect_type_counts),
            'average_power_score': round(sum(power_scores) / len(power_scores), 2) if power_scores else 0,
            'max_power_score': max(power_scores) if power_scores else 0,
            'min_power_score': min(power_scores) if power_scores else 0,
            'high_power_card_ids': high_power_card_ids,
            'most_used_card_ids': most_used_card_ids,
            'orphan_card_count': len(orphan_cards),
        },
        'card_pool_detail': card_pool_detail,
        'card_usage_index': card_usage_index,
        'unused_cards': unused_cards,
        'orphan_card_count': len(orphan_cards),
        'orphan_cards': orphan_cards,
        'sequence_detail': sequence_detail,
        'missing_reports': missing_reports,
        'latest_evaluation_snapshot_path': to_relative(EVALUATION_SNAPSHOT_DIR / f'{profile_id}__{content_pack_id}__evaluation_snapshot.json') if evaluation_snapshot else '',
        'latest_rebuild_recommendation_path': to_relative(REBUILD_RECOMMEND_DIR / f'{profile_id}__{content_pack_id}__rebuild_recommendations.json') if rebuild_recommendations else '',
        'original_content_pack_id': snapshot_summary.get('source_content_pack_id') or content_pack_summary.get('original_content_pack_id'),
        'snapshot_content_pack_id': snapshot_summary.get('snapshot_content_pack_id') or content_pack_summary.get('snapshot_content_pack_id'),
    }
    json_path = detail_pack_json_path(profile_id, content_pack_id)
    md_path = detail_pack_md_path(profile_id, content_pack_id)
    write_json(json_path, detail)
    md_path.write_text(build_pack_markdown(detail), encoding='utf-8')


def build_profile_markdown(detail: dict[str, Any]) -> str:
    lines = [
        f"# 机制包明细：{detail['mechanic_profile_id']}",
        '',
        f"- display_name: {detail.get('display_name', '')}",
        f"- version: {detail.get('version', '')}",
        f"- active_pack_id: {detail.get('active_pack_id', '(none)') or '(none)'}",
        f"- target_sequence_id: {detail.get('target_sequence_id', '')}",
        f"- replacement_mode: {detail.get('replacement_mode', '')}",
        f"- runtime_primitives: {', '.join(detail.get('runtime_primitives', [])) or '-'}",
        f"- allowed_runtime_effects: {', '.join(detail.get('allowed_runtime_effects', [])) or '-'}",
        f"- 是否有武境/收式限制: {'是' if detail.get('card_eligibility_rules') else '否'}",
        '',
        '## 这套机制能支持什么',
        f"- resources: {', '.join(detail.get('resources', [])) or '-'}",
        f"- card_types: {', '.join(detail.get('card_types', [])) or '-'}",
        f"- weapon_styles: {', '.join(detail.get('weapon_styles', [])) or '-'}",
        '',
        '## content packs',
    ]
    for pack in detail.get('profile_pack_list', []):
        lines.append(f"- {pack.get('content_pack_id','')} | mode={pack.get('pack_storage_mode','')} | active={str(pack.get('is_active_pack', False)).lower()} | export={str(pack.get('ready_for_runtime_export', False)).lower()}")
    if detail.get('missing_fields'):
        lines.extend(['', '## missing_fields'])
        for field in detail['missing_fields']:
            lines.append(f'- {field}')
    return '\n'.join(lines) + '\n'


def build_pack_markdown(detail: dict[str, Any]) -> str:
    lines = [
        f"# 内容包明细：{detail['mechanic_profile_id']} / {detail['content_pack_id']}",
        '',
        f"- pack_storage_mode: {detail.get('pack_storage_mode', '')}",
        f"- is_active_pack: {str(detail.get('is_active_pack', False)).lower()}",
        f"- formal_encounter_total_count: {detail.get('formal_encounter_total_count', 0)}",
        f"- card_count: {detail.get('card_count', 0)}",
        f"- deck_count: {detail.get('deck_count', 0)}",
        f"- battle_slot_count: {detail.get('battle_slot_count', 0)}",
        f"- reward_count: {detail.get('reward_count', 0)}",
        '',
        '## 包总体状态',
        f"- ready_for_runtime_export: {str(detail.get('validation_summary', {}).get('ready_for_runtime_export', False)).lower()}",
        f"- sequence_balance_pass: {str(detail.get('validation_summary', {}).get('sequence_balance_pass', False)).lower()}",
        f"- deck_card_realm_eligibility_valid: {str(detail.get('validation_summary', {}).get('deck_card_realm_eligibility_valid', False)).lower()}",
        f"- evaluation_event_count: {detail.get('evaluation_summary', {}).get('evaluation_event_count', 0)}",
        f"- win_rate: {detail.get('evaluation_summary', {}).get('pack_metrics', {}).get('win_rate', 0)}",
        f"- avg_turn_count: {detail.get('evaluation_summary', {}).get('pack_metrics', {}).get('avg_turn_count', 0)}",
        f"- rebuild_recommendation_count: {detail.get('evaluation_summary', {}).get('rebuild_recommendation_count', detail.get('rebuild_recommendation_summary', {}).get('recommendation_count', 0))}",
        '',
        '## 整体卡池',
        f"- used_card_count: {detail.get('card_pool_summary', {}).get('used_card_count', 0)}",
        f"- unused_card_count: {detail.get('card_pool_summary', {}).get('unused_card_count', 0)}",
        f"- orphan_card_count: {detail.get('card_pool_summary', {}).get('orphan_card_count', 0)}",
        f"- high_power_card_ids: {', '.join(detail.get('card_pool_summary', {}).get('high_power_card_ids', [])) or '-'}",
        f"- most_used_card_ids: {', '.join(detail.get('card_pool_summary', {}).get('most_used_card_ids', [])) or '-'}",
        '',
        '## 15 场战斗明细表',
    ]
    for seq in detail.get('sequence_detail', []):
        lines.append(f"- #{seq.get('sequence_position')} {seq.get('formal_encounter_id')} -> slot={seq.get('generated_battle_slot_id')} deck={seq.get('generated_deck_id')} reward={seq.get('reward_plan_id')} wujing_cap={seq.get('player_wujing_cap')} runtime_primitives={','.join(seq.get('runtime_primitives', [])) or '-'}")
    if detail.get('missing_reports'):
        lines.extend(['', '## missing_reports'])
        for report in detail['missing_reports']:
            lines.append(f'- {report}')
    return '\n'.join(lines) + '\n'


def detail_pack_json_path(profile_id: str, content_pack_id: str) -> Path:
    return DETAILS_DIR / f'pack_{profile_id}__{content_pack_id}.json'


def detail_pack_md_path(profile_id: str, content_pack_id: str) -> Path:
    return DETAILS_DIR / f'pack_{profile_id}__{content_pack_id}.md'


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def try_read_json(path: Path) -> Any:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    raise SystemExit(main())
