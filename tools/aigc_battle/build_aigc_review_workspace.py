#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_aigc_content_index as index_lib
from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import switch_active_profile as switch_lib
from tools.aigc_battle import aigc_release_gate as release_lib

GENERATED_ROOT = ROOT / 'data' / 'aigc_battle' / 'generated'
REVIEW_DIR = GENERATED_ROOT / 'review'
REVIEW_NOTES_DIR = ROOT / 'data' / 'aigc_battle' / 'review_notes'
FACTORY_LOG_DIR = GENERATED_ROOT / 'factory_logs'
ACTIVE_HISTORY_PATH = ROOT / 'data' / 'aigc_battle' / 'runtime' / 'active_profile_history.jsonl'
WORKSPACE_JSON = REVIEW_DIR / 'aigc_review_workspace.json'
WORKSPACE_MD = REVIEW_DIR / 'aigc_review_workspace.md'
COMPARE_JSON = REVIEW_DIR / 'pack_compare_matrix.json'
COMPARE_MD = REVIEW_DIR / 'pack_compare_matrix.md'

SEVERITY_WEIGHT = {'fail': 0, 'warning': 1, 'info': 2}


def main() -> int:
    index_payload = index_lib.build_index()
    REVIEW_DIR.mkdir(parents=True, exist_ok=True)

    pack_reviews: list[dict[str, Any]] = []
    compare_rows: list[dict[str, Any]] = []
    all_risks: list[dict[str, Any]] = []

    for profile in index_payload.get('profiles', []):
        profile_id = str(profile.get('mechanic_profile_id', ''))
        for pack_entry in profile.get('content_packs', []):
            content_pack_id = str(pack_entry.get('content_pack_id', ''))
            detail_path = detail_lib.detail_pack_json_path(profile_id, content_pack_id)
            detail = detail_lib.try_read_json(detail_path)
            pack_review = build_pack_review(index_payload, profile_id, pack_entry, detail)
            review_json_path = pack_review_json_path(profile_id, content_pack_id)
            review_md_path = pack_review_md_path(profile_id, content_pack_id)
            report_md_path = review_report_md_path(profile_id, content_pack_id)
            write_json(review_json_path, pack_review)
            review_md_path.write_text(build_pack_review_markdown(pack_review), encoding='utf-8')
            report_md_path.write_text(build_review_report_markdown(pack_review), encoding='utf-8')

            pack_reviews.append({
                'mechanic_profile_id': profile_id,
                'content_pack_id': content_pack_id,
                'is_active_pack': bool(pack_review['pack_identity']['is_active_pack']),
                'health_status': pack_review['health_summary']['health_status'],
                'health_score': pack_review['health_summary']['health_score'],
                'review_status': pack_review.get('review_status', 'pending'),
                'reviewer': pack_review.get('reviewer', ''),
                'recommended_action': pack_review.get('recommended_action', ''),
                'release_status': pack_review.get('release_status', 'draft'),
                'frozen': bool(pack_review.get('frozen', False)),
                'release_candidate': bool(pack_review.get('release_candidate', False)),
                'archived': bool(pack_review.get('archived', False)),
                'risk_count': pack_review['risk_summary']['risk_count'],
                'fail_count': pack_review['risk_summary']['fail_count'],
                'warning_count': pack_review['risk_summary']['warning_count'],
                'info_count': pack_review['risk_summary']['info_count'],
                'pack_review_json_path': to_relative(review_json_path),
                'pack_review_md_path': to_relative(review_md_path),
                'review_report_md_path': to_relative(report_md_path),
                'missing_detail': bool(pack_review.get('missing_detail', False)),
                'evaluated': bool(pack_review.get('evaluation_summary', {}).get('evaluated', False)),
                'evaluation_event_count': int(pack_review.get('evaluation_summary', {}).get('evaluation_event_count', 0)),
                'win_rate': float(pack_review.get('evaluation_summary', {}).get('win_rate', 0)),
                'avg_turn_count': float(pack_review.get('evaluation_summary', {}).get('avg_turn_count', 0)),
                'avg_player_hp_end': float(pack_review.get('evaluation_summary', {}).get('avg_player_hp_end', 0)),
                'mechanic_trigger_rate': float(pack_review.get('evaluation_summary', {}).get('runtime_primitive_trigger_rate', 0)),
                'actionability_score': int(pack_review.get('evaluation_summary', {}).get('actionability_score', 0)),
                'needs_rebuild': bool(pack_review.get('evaluation_summary', {}).get('needs_rebuild', False)),
            })
            compare_rows.append(build_compare_row(pack_review))
            all_risks.extend(pack_review['all_risks'])

    compare_matrix = build_compare_matrix(index_payload, compare_rows)
    write_json(COMPARE_JSON, compare_matrix)
    COMPARE_MD.write_text(build_compare_matrix_markdown(compare_matrix), encoding='utf-8')

    recommended_review_order = sorted(
        pack_reviews,
        key=lambda item: (
            health_rank(item['health_status']),
            -int(item['risk_count']),
            int(item['health_score']),
            item['mechanic_profile_id'],
            item['content_pack_id'],
        ),
    )
    active_pack_review = next((item for item in pack_reviews if item.get('is_active_pack')), None)
    workspace = {
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'active_profile_id': index_payload.get('active_profile_id', ''),
        'active_content_pack_id': index_payload.get('active_content_pack_id', ''),
        'release_channels': index_payload.get('release_channels', {}),
        'active_profile_matches_current_release': bool(index_payload.get('active_profile_matches_current_release', False)),
        'active_profile_drift_from_current_release': bool(index_payload.get('active_profile_drift_from_current_release', False)),
        'profile_count': int(index_payload.get('profile_count', 0)),
        'content_pack_count': int(index_payload.get('content_pack_count', 0)),
        'active_pack_review_path': active_pack_review.get('pack_review_json_path', '') if active_pack_review else '',
        'pack_reviews': pack_reviews,
        'compare_matrix': {
            'json_path': to_relative(COMPARE_JSON),
            'md_path': to_relative(COMPARE_MD),
            'summary': {k: v for k, v in compare_matrix.items() if k != 'packs'},
        },
        'global_risk_summary': summarize_risks(all_risks),
        'recommended_review_order': recommended_review_order,
    }
    write_json(WORKSPACE_JSON, workspace)
    WORKSPACE_MD.write_text(build_workspace_markdown(workspace), encoding='utf-8')
    print(f'built aigc review workspace: packs={len(pack_reviews)}')
    return 0


def build_pack_review(index_payload: dict[str, Any], profile_id: str, pack_entry: dict[str, Any], detail: dict[str, Any] | None) -> dict[str, Any]:
    content_pack_id = str(pack_entry.get('content_pack_id', ''))
    if not detail:
        risk = risk_item(
            severity='fail',
            risk_type='missing_detail',
            message='缺少 V9.2 detail JSON，无法生成完整审核视图。',
            profile_id=profile_id,
            content_pack_id=content_pack_id,
            suggested_action='needs_rebuild',
        )
        health = {
            'ready_for_runtime_export': False,
            'full_sequence_coverage_complete': False,
            'runtime_export_allowed': False,
            'sequence_balance_pass': False,
            'all_generated_slots_have_reward': False,
            'fallback_loadout_count': 0,
            'deck_card_realm_eligibility_valid': False,
            'no_card_above_player_wujing_in_deck': False,
            'orphan_card_count': 0,
            'unused_card_count': 0,
            'missing_reports': ['detail_json_missing'],
            'health_score': 0,
            'health_status': 'fail',
        }
        return {
            'pack_identity': {
                'mechanic_profile_id': profile_id,
                'content_pack_id': content_pack_id,
                'sequence_template_id': '',
                'build_variant': '',
                'pack_identity': {},
                'is_active_pack': bool(pack_entry.get('is_active_pack', False)),
                'pack_storage_mode': pack_entry.get('pack_storage_mode', ''),
                'runtime_manifest_path': pack_entry.get('runtime_manifest_path', ''),
                'target_sequence_id': '',
                'replacement_mode': '',
            },
            'health_summary': health,
            'encounter_review_table': [],
            'card_pool_review_table': [],
            'deck_review_table': [],
            'reward_review_table': [],
            'run_pacing_view': [],
            'encounter_design_cards': [],
            'risk_summary': summarize_risks([risk]),
            'visual_filter_options': empty_filter_options(),
            'telemetry_snapshot_status': {},
            'missing_detail': True,
            'all_risks': [risk],
        }

    validation = detail.get('validation_summary', {})
    telemetry = detail.get('telemetry_summary', {})
    snapshot = detail.get('snapshot_summary', {})
    runtime_primitive_summary = detail.get('runtime_primitive_summary', {})
    evaluation = detail.get('evaluation_summary', {}) if isinstance(detail.get('evaluation_summary', {}), dict) else {}
    rebuild_recommendation_summary = detail.get('rebuild_recommendation_summary', {}) if isinstance(detail.get('rebuild_recommendation_summary', {}), dict) else {}
    balance_release_summary = detail.get('balance_release_summary', {}) if isinstance(detail.get('balance_release_summary', {}), dict) else {}
    cards = detail.get('card_pool_detail', [])
    sequences = detail.get('sequence_detail', [])

    high_power_threshold = compute_high_power_threshold(cards)
    card_rows = []
    card_risks: list[dict[str, Any]] = []
    card_power_max = max((float(card.get('power_score', 0) or 0) for card in cards), default=0)
    card_usage_values = sorted((int(card.get('usage_count', 0) or 0) for card in cards), reverse=True)
    high_usage_threshold = max(4, card_usage_values[max(0, math.ceil(len(card_usage_values) * 0.2) - 1)] if card_usage_values else 0)

    deck_cards: dict[str, list[dict[str, Any]]] = {}
    deck_slots: dict[str, list[str]] = defaultdict(list)
    deck_encounters: dict[str, list[dict[str, Any]]] = defaultdict(list)
    reward_usage: dict[str, list[dict[str, Any]]] = defaultdict(list)

    for seq in sequences:
        deck_id = str(seq.get('generated_deck_id', ''))
        slot_id = str(seq.get('generated_battle_slot_id', ''))
        reward_id = str(seq.get('reward_plan_id', ''))
        deck_cards.setdefault(deck_id, seq.get('card_summaries', []))
        if slot_id:
            deck_slots[deck_id].append(slot_id)
        deck_encounters[deck_id].append(seq)
        reward_usage[reward_id].append(seq)

    for card in cards:
        card_id = str(card.get('card_id', ''))
        effect_types = [str(effect.get('type', 'unknown')) for effect in card.get('effects', [])]
        effects_text = '; '.join(format_effect(effect) for effect in card.get('effects', [])) or '-'
        usage_count = int(card.get('usage_count', 0) or 0)
        required_wujing = safe_int(card.get('required_wujing'))
        closing_form_tier = safe_int(card.get('closing_form_tier'))
        is_high_power = float(card.get('power_score', 0) or 0) >= high_power_threshold
        risk_flags: list[str] = []
        if usage_count == 0:
            risk_flags.append('unused_card')
            card_risks.append(risk_item('warning', 'unused_card', '卡牌未进入任何 deck。', profile_id, content_pack_id, card_id=card_id, suggested_action='needs_balance_adjustment'))
        if usage_count >= high_usage_threshold and usage_count > 0:
            risk_flags.append('high_usage_card')
            card_risks.append(risk_item('warning', 'high_usage_card', '卡牌使用频次偏高，建议检查重复占用。', profile_id, content_pack_id, card_id=card_id, suggested_action='needs_balance_adjustment'))
        if is_high_power:
            risk_flags.append('high_power_card')
        card_rows.append({
            'card_id': card_id,
            'name': card.get('name', ''),
            'card_type': card.get('card_type', ''),
            'weapon_style': card.get('weapon_style', ''),
            'cost': card.get('cost'),
            'effects_text': effects_text,
            'effect_types': sorted(set(effect_types)),
            'tags': card.get('tags', []),
            'difficulty_tier': card.get('difficulty_tier', ''),
            'power_score': float(card.get('power_score', 0) or 0),
            'required_wujing': required_wujing,
            'closing_form_tier': closing_form_tier,
            'usage_count': usage_count,
            'used_in_deck_count': len(card.get('used_in_deck_ids', [])),
            'used_in_battle_slot_count': len(card.get('used_in_battle_slot_ids', [])),
            'is_unused': usage_count == 0,
            'is_high_power': is_high_power,
            'realm_requirement_label': f'武境{required_wujing}/收式{closing_form_tier}',
            'risk_flags': risk_flags,
        })

    card_row_by_id = {row['card_id']: row for row in card_rows}
    encounter_rows: list[dict[str, Any]] = []
    encounter_risks: list[dict[str, Any]] = []
    deck_power_values: list[float] = []
    deck_rows_map: dict[str, dict[str, Any]] = {}
    deck_risks: list[dict[str, Any]] = []

    for seq in sequences:
        deck_id = str(seq.get('generated_deck_id', ''))
        slot_id = str(seq.get('generated_battle_slot_id', ''))
        reward_id = str(seq.get('reward_plan_id', ''))
        cards_in_deck = deck_cards.get(deck_id, seq.get('card_summaries', []))
        power_score = float(seq.get('deck_power_score', 0) or 0)
        deck_power_values.append(power_score)
        target_min = float(seq.get('target_power_min', 0) or 0)
        target_max = float(seq.get('target_power_max', 0) or 0)
        player_wujing_cap = safe_int(seq.get('player_wujing_cap'))
        enemy_role = str(seq.get('deck_summary', {}).get('enemy_role', ''))
        difficulty_tier = str(seq.get('deck_summary', {}).get('difficulty_tier', ''))
        high_power_cards = [card for card in cards_in_deck if card_row_by_id.get(str(card.get('card_id', '')), {}).get('is_high_power')]
        max_required_wujing = max((safe_int(card.get('required_wujing')) for card in cards_in_deck), default=0)
        max_closing_form_tier = max((safe_int(card.get('closing_form_tier')) for card in cards_in_deck), default=0)
        realm_valid = all(bool(card.get('realm_eligible_for_slot', True)) for card in cards_in_deck)
        pressure_summary = summarize_opening_pressure(seq.get('opening_pressure'))
        risk_flags: list[str] = []

        if not deck_id:
            risk_flags.append('missing_deck')
            encounter_risks.append(risk_item('fail', 'battle_slot_missing_deck', 'battle_slot 缺少 deck。', profile_id, content_pack_id, formal_encounter_id=str(seq.get('formal_encounter_id', '')), suggested_action='needs_rebuild'))
        if not reward_id:
            risk_flags.append('missing_reward')
            encounter_risks.append(risk_item('fail', 'battle_slot_missing_reward', 'battle_slot 缺少 reward。', profile_id, content_pack_id, formal_encounter_id=str(seq.get('formal_encounter_id', '')), suggested_action='needs_rebuild'))
        if not realm_valid:
            risk_flags.append('realm_invalid')
            encounter_risks.append(risk_item('fail', 'deck_card_realm_invalid', 'deck 内存在超出当前玩家武境/收式上限的卡牌。', profile_id, content_pack_id, formal_encounter_id=str(seq.get('formal_encounter_id', '')), deck_id=deck_id, suggested_action='blocked_by_validation'))
        if target_max and power_score >= target_max - max(1.0, (target_max - target_min) * 0.1):
            risk_flags.append('close_to_target_power_max')
            encounter_risks.append(risk_item('warning', 'deck_power_close_to_max', 'deck power 接近 target_power_max。', profile_id, content_pack_id, formal_encounter_id=str(seq.get('formal_encounter_id', '')), deck_id=deck_id, suggested_action='needs_balance_adjustment'))
        if target_min and power_score <= target_min + max(1.0, (target_max - target_min) * 0.1):
            risk_flags.append('close_to_target_power_min')
            encounter_risks.append(risk_item('warning', 'deck_power_close_to_min', 'deck power 接近 target_power_min。', profile_id, content_pack_id, formal_encounter_id=str(seq.get('formal_encounter_id', '')), deck_id=deck_id, suggested_action='needs_balance_adjustment'))
        if high_power_cards and str(seq.get('encounter_tier', '')) == 'early':
            risk_flags.append('early_high_power_card')
            encounter_risks.append(risk_item('warning', 'early_high_power_card', 'early encounter 出现高 power 卡。', profile_id, content_pack_id, formal_encounter_id=str(seq.get('formal_encounter_id', '')), deck_id=deck_id, suggested_action='needs_balance_adjustment'))
        if player_wujing_cap and max_required_wujing >= player_wujing_cap:
            risk_flags.append('realm_cap_close')
            encounter_risks.append(risk_item('warning', 'required_wujing_close_to_cap', '卡牌武境要求接近玩家上限。', profile_id, content_pack_id, formal_encounter_id=str(seq.get('formal_encounter_id', '')), deck_id=deck_id, suggested_action='needs_balance_adjustment'))
        if seq.get('opening_pressure') and not runtime_primitive_summary:
            risk_flags.append('opening_pressure_probe_missing')
            encounter_risks.append(risk_item('warning', 'opening_pressure_probe_missing', '存在 opening_pressure，但缺少 probe 细节。', profile_id, content_pack_id, formal_encounter_id=str(seq.get('formal_encounter_id', '')), suggested_action='needs_real_telemetry'))
        if seq.get('runtime_primitives'):
            encounter_risks.append(risk_item('info', 'runtime_primitive_present', '该 encounter 使用了 runtime primitive。', profile_id, content_pack_id, formal_encounter_id=str(seq.get('formal_encounter_id', '')), deck_id=deck_id, suggested_action='ready_for_review'))

        encounter_row = {
            'sequence_position': safe_int(seq.get('sequence_position')),
            'formal_encounter_id': str(seq.get('formal_encounter_id', '')),
            'formal_battle_id': str(seq.get('formal_battle_id', '')),
            'node_id': str(seq.get('node_id', '')),
            'node_type': str(seq.get('node_type', '')),
            'encounter_tier': str(seq.get('encounter_tier', '')),
            'encounter_kind': str(seq.get('encounter_kind', '')),
            'generated_battle_slot_id': slot_id,
            'generated_deck_id': deck_id,
            'reward_plan_id': reward_id,
            'enemy_role': enemy_role,
            'difficulty_tier': difficulty_tier,
            'deck_power_score': round(power_score, 2),
            'target_power_min': target_min,
            'target_power_max': target_max,
            'power_range_pass': bool(seq.get('power_range_pass', False)),
            'reward_tier': str(seq.get('reward_tier', seq.get('reward_summary', {}).get('reward_tier', ''))),
            'player_wujing_cap': player_wujing_cap,
            'card_count': len(cards_in_deck),
            'high_power_card_count': len(high_power_cards),
            'max_required_wujing': max_required_wujing,
            'max_closing_form_tier': max_closing_form_tier,
            'realm_valid': realm_valid,
            'runtime_primitives': seq.get('runtime_primitives', []),
            'opening_pressure_summary': pressure_summary,
            'risk_flags': risk_flags,
            'deck_cards': cards_in_deck,
        }
        encounter_rows.append(encounter_row)

        if deck_id not in deck_rows_map:
            deck_rows_map[deck_id] = build_deck_row(profile_id, content_pack_id, deck_id, seq, cards_in_deck, high_power_threshold, deck_slots, deck_encounters)
            deck_risks.extend(deck_rows_map[deck_id].pop('_risks'))

    reward_rows: list[dict[str, Any]] = []
    reward_risks: list[dict[str, Any]] = []
    for reward_id, usages in sorted(reward_usage.items()):
        reward_summary = usages[0].get('reward_summary', {})
        encounter_tiers = sorted({str(item.get('encounter_tier', '')) for item in usages if item.get('encounter_tier')})
        reward_tier = str(reward_summary.get('reward_tier', usages[0].get('reward_tier', '')))
        risk_flags: list[str] = []
        if not reward_tier:
            risk_flags.append('reward_tier_missing')
            reward_risks.append(risk_item('warning', 'reward_tier_missing', 'reward 缺少 reward_tier。', profile_id, content_pack_id, suggested_action='needs_rebuild'))
        if reward_tier and encounter_tiers and any(tier_rank(reward_tier) + 1 < tier_rank(tier) for tier in encounter_tiers):
            risk_flags.append('reward_tier_lower_than_encounter')
            reward_risks.append(risk_item('warning', 'reward_tier_lower_than_encounter', 'reward_tier 低于 encounter tier。', profile_id, content_pack_id, suggested_action='needs_balance_adjustment'))
        reward_rows.append({
            'reward_plan_id': reward_id,
            'reward_type': str(reward_summary.get('reward_type', '')),
            'reward_tier': reward_tier,
            'reward_items_text': format_reward_items(reward_summary.get('reward_items', [])),
            'used_by_battle_slots': [str(item.get('generated_battle_slot_id', '')) for item in usages if item.get('generated_battle_slot_id')],
            'matched_encounter_tier': encounter_tiers,
            'risk_flags': risk_flags,
        })

    telemetry_risks: list[dict[str, Any]] = []
    if not telemetry:
        telemetry_risks.append(risk_item('warning', 'telemetry_missing', '缺少 telemetry 明细。', profile_id, content_pack_id, suggested_action='needs_real_telemetry'))
    if not snapshot:
        telemetry_risks.append(risk_item('warning', 'snapshot_missing', '缺少 snapshot 明细。', profile_id, content_pack_id, suggested_action='needs_real_telemetry'))
    if telemetry.get('telemetry_detail_level') == 'minimal':
        telemetry_risks.append(risk_item('info', 'telemetry_detail_level_minimal', 'telemetry 明细级别为 minimal。', profile_id, content_pack_id, suggested_action='needs_real_telemetry'))
    if snapshot.get('flag_only'):
        telemetry_risks.append(risk_item('info', 'snapshot_flag_only', 'snapshot 当前仅标记 flag。', profile_id, content_pack_id, suggested_action='needs_real_telemetry'))
    if detail.get('original_content_pack_id') or detail.get('snapshot_content_pack_id'):
        telemetry_risks.append(risk_item('info', 'snapshot_pack', '当前 pack 含 snapshot 关系信息。', profile_id, content_pack_id, suggested_action='ready_for_review'))
    ai_trace = detail.get('ai_source_trace', {})
    if 'llm_candidate' in profile_id or 'llm_candidate' in content_pack_id or ai_trace.get('llm_candidate_source'):
        telemetry_risks.append(risk_item('info', 'llm_candidate_import_source', '当前 pack 含 llm candidate import 来源。', profile_id, content_pack_id, suggested_action='ready_for_review'))
    if ai_trace.get('deterministic_fill_used'):
        telemetry_risks.append(risk_item('warning', 'deterministic_fill_used', 'AI pack 使用了 deterministic fill。', profile_id, content_pack_id, suggested_action='needs_review'))
    if int(ai_trace.get('rejected_candidate_count', 0)) > 0:
        telemetry_risks.append(risk_item('warning', 'rejected_candidate_count_present', '当前 AI pack 上下文存在 rejected candidates。', profile_id, content_pack_id, suggested_action='needs_review'))
    if ai_trace.get('llm_candidate_source') and not ai_trace.get('candidate_diff_report_path'):
        telemetry_risks.append(risk_item('warning', 'ai_pack_missing_candidate_diff', 'AI pack 缺少 candidate diff 报告。', profile_id, content_pack_id, suggested_action='needs_rebuild'))

    validation_risks = build_validation_risks(profile_id, content_pack_id, detail, encounter_rows)
    all_risks = validation_risks + encounter_risks + card_risks + deck_risks + reward_risks + telemetry_risks

    risk_summary = summarize_risks(all_risks)
    health_summary = build_health_summary(detail, risk_summary)
    review_notes = load_review_notes(profile_id, content_pack_id)
    release_status = release_lib.get_release_status(profile_id, content_pack_id)
    active_history_summary = build_active_history_summary(profile_id, content_pack_id)
    factory_log_summary = build_factory_log_summary(profile_id, content_pack_id)
    run_pacing_view = [
        {
            'sequence_position': row['sequence_position'],
            'formal_encounter_id': row['formal_encounter_id'],
            'encounter_tier': row['encounter_tier'],
            'encounter_kind': row['encounter_kind'],
            'deck_power_score': row['deck_power_score'],
            'target_power_min': row['target_power_min'],
            'target_power_max': row['target_power_max'],
            'reward_tier': row['reward_tier'],
            'player_wujing_cap': row['player_wujing_cap'],
            'runtime_primitives': row['runtime_primitives'],
            'opening_pressure_value': extract_opening_pressure_value(row['opening_pressure_summary']),
            'risk_flags': row['risk_flags'],
        }
        for row in sorted(encounter_rows, key=lambda item: item['sequence_position'])
    ]

    design_cards = [
        build_encounter_design_card(row, deck_rows_map.get(row['generated_deck_id'], {}), reward_rows)
        for row in sorted(encounter_rows, key=lambda item: item['sequence_position'])
    ]
    visual_filter_options = build_filter_options(encounter_rows, card_rows, list(deck_rows_map.values()), reward_rows, all_risks)
    recommended_action = recommend_action(health_summary, risk_summary, telemetry, snapshot)

    return {
        'pack_identity': {
            'mechanic_profile_id': profile_id,
            'content_pack_id': content_pack_id,
            'sequence_template_id': str(detail.get('sequence_template_id', '')),
            'template_display_name': str(detail.get('template_display_name', detail.get('sequence_template_id', ''))),
            'template_usage_recommendation': str(detail.get('template_usage_recommendation', '')),
            'build_variant': str(detail.get('build_variant', '')),
            'matrix_slot': bool(detail.get('matrix_slot', False)),
            'matrix_build_variant': str(detail.get('matrix_build_variant', '')),
            'matrix_strategy_tag': str(detail.get('matrix_strategy_tag', '')),
            'pack_identity': detail.get('pack_identity', {}),
            'stage_counts': detail.get('stage_counts', {}),
            'template_mechanic_pack_binding_valid': bool(detail.get('template_mechanic_pack_binding_valid', False)),
            'is_active_pack': bool(pack_entry.get('is_active_pack', False)),
            'pack_storage_mode': str(detail.get('pack_storage_mode', pack_entry.get('pack_storage_mode', ''))),
            'runtime_manifest_path': str(detail.get('runtime_manifest_path', '')),
            'target_sequence_id': str(detail.get('target_sequence_id', '')),
            'replacement_mode': str(detail.get('replacement_mode', '')),
        },
        'health_summary': health_summary,
        'encounter_review_table': sorted(encounter_rows, key=lambda item: item['sequence_position']),
        'card_pool_review_table': sorted(card_rows, key=lambda item: (-item['usage_count'], item['card_id'])),
        'deck_review_table': sorted(deck_rows_map.values(), key=lambda item: (-float(item.get('deck_power_score', 0) or 0), item['deck_id'])),
        'reward_review_table': sorted(reward_rows, key=lambda item: (tier_rank(item['reward_tier']), item['reward_plan_id'])),
        'run_pacing_view': run_pacing_view,
        'encounter_design_cards': design_cards,
        'risk_summary': risk_summary,
        'visual_filter_options': visual_filter_options,
        'telemetry_snapshot_status': {
            'telemetry_summary': telemetry,
            'snapshot_summary': snapshot,
            'runtime_primitive_summary': runtime_primitive_summary,
            'missing_reports': detail.get('missing_reports', []),
        },
        'evaluation_summary': {
            'evaluated': bool(evaluation),
            'evaluation_event_count': int(evaluation.get('evaluation_event_count', 0) or 0),
            'sequence_template_id': str(detail.get('sequence_template_id', '')),
            'telemetry_detail_level_summary': evaluation.get('telemetry_detail_level_summary', {}),
            'win_rate': float(evaluation.get('pack_metrics', {}).get('win_rate', 0) or 0),
            'avg_turn_count': float(evaluation.get('pack_metrics', {}).get('avg_turn_count', 0) or 0),
            'avg_player_hp_end': float(evaluation.get('pack_metrics', {}).get('avg_player_hp_end', 0) or 0),
            'avg_damage_taken': float(evaluation.get('pack_metrics', {}).get('avg_damage_taken', 0) or 0),
            'runtime_primitive_trigger_rate': float(evaluation.get('mechanic_metrics', {}).get('runtime_primitive_trigger_rate', evaluation.get('pack_metrics', {}).get('runtime_primitive_trigger_rate', 0) or 0) or 0),
            'stage_metrics': evaluation.get('stage_metrics', {}),
            'mechanism_underused_candidates': evaluation.get('mechanism_underused_candidates', []),
            'too_easy_candidates': evaluation.get('too_easy_candidates', []),
            'too_hard_candidates': evaluation.get('too_hard_candidates', []),
            'too_long_candidates': evaluation.get('too_long_candidates', []),
            'reward_mismatch_candidates': evaluation.get('reward_mismatch_candidates', []),
            'rebuild_recommendation_count': int(evaluation.get('rebuild_recommendation_count', rebuild_recommendation_summary.get('recommendation_count', 0) or 0)),
            'actionability_score': int(evaluation.get('actionability_score', 0) or 0),
            'latest_evaluation_snapshot_path': detail.get('latest_evaluation_snapshot_path', ''),
            'latest_rebuild_recommendation_path': detail.get('latest_rebuild_recommendation_path', ''),
            'needs_rebuild': bool(int(evaluation.get('rebuild_recommendation_count', rebuild_recommendation_summary.get('recommendation_count', 0) or 0)) > 0),
        },
        'template_release_strategy': detail.get('template_release_strategy', {}),
        'template_portfolio_metrics': detail.get('template_portfolio_metrics', {}),
        'matrix_evaluation_summary': detail.get('matrix_evaluation_summary', {}),
        'needs_balance_before_release': bool(detail.get('needs_balance_before_release', False)),
        'ready_for_candidate_review': bool(detail.get('ready_for_candidate_review', False)),
        'balance_release_summary': balance_release_summary,
        'review_report_path': to_relative(review_report_md_path(profile_id, content_pack_id)),
        'review_notes_summary': review_notes,
        'review_status': review_notes.get('review_status', 'pending'),
        'reviewer': review_notes.get('reviewer', ''),
        'recommended_action': review_notes.get('recommended_action', recommended_action),
        'llm_candidate_source': bool(ai_trace.get('llm_candidate_source', False)),
        'accepted_candidate_count': int(ai_trace.get('accepted_candidate_count', 0)),
        'rejected_candidate_count': int(ai_trace.get('rejected_candidate_count', 0)),
        'deterministic_fill_used': bool(ai_trace.get('deterministic_fill_used', False)),
        'candidate_diff_summary': load_optional_json(ai_trace.get('candidate_diff_report_path', '')),
        'candidate_rejection_summary': load_optional_json(ai_trace.get('candidate_import_report_path', '')),
        'ai_pack_ready_for_review': bool(ai_trace.get('built_from_llm_candidates', False)),
        'release_status': release_status.get('release_status', 'draft'),
        'frozen': bool(release_status.get('frozen', False)),
        'release_candidate': release_status.get('release_status') == 'release_candidate',
        'active_release': release_status.get('release_status') == 'active',
        'archived': release_status.get('release_status') == 'archived',
        'rollback_available': bool(release_status.get('rollback_available', False)),
        'suggested_git_commands': {
            'suggested_git_commit_command': release_status.get('suggested_git_commit_command', ''),
            'suggested_git_tag_command': release_status.get('suggested_git_tag_command', ''),
        },
        'active_history_summary': active_history_summary,
        'factory_log_summary': factory_log_summary,
        'all_risks': all_risks,
        'recommended_action': review_notes.get('recommended_action', recommended_action),
        'missing_detail': False,
    }


def build_deck_row(
    profile_id: str,
    content_pack_id: str,
    deck_id: str,
    seq: dict[str, Any],
    cards_in_deck: list[dict[str, Any]],
    high_power_threshold: float,
    deck_slots: dict[str, list[str]],
    deck_encounters: dict[str, list[dict[str, Any]]],
) -> dict[str, Any]:
    scores = score_deck(cards_in_deck)
    max_required_wujing = max((safe_int(card.get('required_wujing')) for card in cards_in_deck), default=0)
    max_closing_form_tier = max((safe_int(card.get('closing_form_tier')) for card in cards_in_deck), default=0)
    player_wujing_cap = safe_int(seq.get('player_wujing_cap'))
    power_score = float(seq.get('deck_power_score', 0) or 0)
    card_ids = [str(card.get('card_id', '')) for card in cards_in_deck]
    duplicate_max = max(Counter(card_ids).values(), default=0)
    risk_flags: list[str] = []
    risks: list[dict[str, Any]] = []

    if duplicate_max >= 3:
        risk_flags.append('repeated_cards_in_deck')
        risks.append(risk_item('warning', 'repeated_cards_in_deck', '同一 deck 内重复卡偏多。', profile_id, content_pack_id, deck_id=deck_id, suggested_action='needs_balance_adjustment'))
    if player_wujing_cap and max_required_wujing > player_wujing_cap:
        risk_flags.append('realm_invalid')
        risks.append(risk_item('fail', 'deck_card_realm_invalid', 'deck 卡牌超出玩家武境上限。', profile_id, content_pack_id, deck_id=deck_id, suggested_action='blocked_by_validation'))

    deck_row = {
        'deck_id': deck_id,
        'enemy_role': str(seq.get('deck_summary', {}).get('enemy_role', '')),
        'difficulty_tier': str(seq.get('deck_summary', {}).get('difficulty_tier', '')),
        'deck_power_score': round(power_score, 2),
        'target_power_min': float(seq.get('target_power_min', 0) or 0),
        'target_power_max': float(seq.get('target_power_max', 0) or 0),
        'power_range_pass': bool(seq.get('power_range_pass', False)),
        'card_count': len(cards_in_deck),
        'unique_card_count': len(set(card_ids)),
        'high_power_card_count': sum(1 for card in cards_in_deck if float(card.get('power_score', 0) or 0) >= high_power_threshold),
        'max_required_wujing': max_required_wujing,
        'max_closing_form_tier': max_closing_form_tier,
        'player_wujing_cap': player_wujing_cap,
        'realm_valid': all(bool(card.get('realm_eligible_for_slot', True)) for card in cards_in_deck),
        'used_by_battle_slots': sorted(set(deck_slots.get(deck_id, []))),
        'deck_archetype': scores['deck_archetype'],
        'aggression_score': scores['aggression_score'],
        'defense_score': scores['defense_score'],
        'momentum_score': scores['momentum_score'],
        'break_score': scores['break_score'],
        'pressure_profile': scores['pressure_profile'],
        'risk_flags': risk_flags,
        'cards': cards_in_deck,
        '_risks': risks,
    }
    return deck_row


def build_validation_risks(profile_id: str, content_pack_id: str, detail: dict[str, Any], encounter_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    validation = detail.get('validation_summary', {})
    card_pool_summary = detail.get('card_pool_summary', {})
    missing_reports = detail.get('missing_reports', [])
    risks: list[dict[str, Any]] = []

    fail_checks = [
        ('full_sequence_coverage_complete', bool(validation.get('full_sequence_coverage_complete', False)), '全序列 coverage 未完成。', 'blocked_by_validation'),
        ('ready_for_runtime_export', bool(validation.get('ready_for_runtime_export', False)), '内容包未准备好导出 runtime。', 'blocked_by_runtime'),
        ('runtime_export_allowed', bool(validation.get('runtime_export_allowed', False)), 'runtime export gate 未通过。', 'blocked_by_runtime'),
        ('sequence_balance_pass', bool(validation.get('sequence_balance_pass', False)), 'sequence balance gate 未通过。', 'needs_balance_adjustment'),
        ('deck_card_realm_eligibility_valid', bool(validation.get('deck_card_realm_eligibility_valid', False)), 'deck card realm eligibility 未通过。', 'blocked_by_validation'),
        ('no_card_above_player_wujing_in_deck', bool(validation.get('no_card_above_player_wujing_in_deck', False)), '存在卡牌超过玩家武境上限。', 'blocked_by_validation'),
    ]
    for risk_type, passed, message, action in fail_checks:
        if not passed:
            risks.append(risk_item('fail', risk_type, message, profile_id, content_pack_id, suggested_action=action))

    fallback_count = int(detail.get('telemetry_summary', {}).get('fallback_telemetry_event_count', 0) or 0)
    if fallback_count > 0:
        risks.append(risk_item('fail', 'fallback_loadout_present', '存在 fallback loadout 事件。', profile_id, content_pack_id, suggested_action='needs_rebuild'))
    orphan_count = int(detail.get('orphan_card_count', 0) or 0)
    if orphan_count > 0:
        risks.append(risk_item('fail', 'orphan_card_present', '存在 deck 引用缺失卡牌。', profile_id, content_pack_id, suggested_action='needs_rebuild'))
    for orphan in detail.get('orphan_cards', []):
        risks.append(risk_item('fail', 'card_referenced_but_missing', 'deck 引用了缺失 card。', profile_id, content_pack_id, deck_id=str(orphan.get('deck_id', '')), card_id=str(orphan.get('card_id', '')), suggested_action='needs_rebuild'))

    if int(card_pool_summary.get('unused_card_count', 0) or 0) > 0:
        risks.append(risk_item('warning', 'unused_card_count_present', '存在未使用卡牌。', profile_id, content_pack_id, suggested_action='needs_balance_adjustment'))
    if missing_reports:
        for report_name in missing_reports:
            risks.append(risk_item('warning', 'missing_report', f'缺少审核依赖报告：{report_name}', profile_id, content_pack_id, suggested_action='needs_rebuild'))

    style_counts = Counter(row.get('weapon_style', '') for row in detail.get('card_pool_detail', []) if row.get('weapon_style'))
    type_counts = Counter(row.get('card_type', '') for row in detail.get('card_pool_detail', []) if row.get('card_type'))
    total_cards = max(1, len(detail.get('card_pool_detail', [])))
    if style_counts and max(style_counts.values()) / total_cards >= 0.8:
        risks.append(risk_item('warning', 'weapon_style_distribution_imbalanced', 'weapon_style 分布偏斜。', profile_id, content_pack_id, suggested_action='needs_balance_adjustment'))
    if type_counts and max(type_counts.values()) / total_cards >= 0.7:
        risks.append(risk_item('warning', 'card_type_distribution_imbalanced', 'card_type 分布偏斜。', profile_id, content_pack_id, suggested_action='needs_balance_adjustment'))

    for row in encounter_rows:
        if not row.get('reward_plan_id'):
            risks.append(risk_item('fail', 'battle_slot_missing_reward', 'battle_slot 缺少 reward。', profile_id, content_pack_id, formal_encounter_id=row.get('formal_encounter_id', ''), deck_id=row.get('generated_deck_id', ''), suggested_action='needs_rebuild'))
        if not row.get('generated_deck_id'):
            risks.append(risk_item('fail', 'battle_slot_missing_deck', 'battle_slot 缺少 deck。', profile_id, content_pack_id, formal_encounter_id=row.get('formal_encounter_id', ''), suggested_action='needs_rebuild'))
    return risks


def build_health_summary(detail: dict[str, Any], risk_summary: dict[str, Any]) -> dict[str, Any]:
    validation = detail.get('validation_summary', {})
    all_generated_slots_have_reward = all(bool(row.get('reward_plan_id')) for row in detail.get('sequence_detail', []))
    fallback_loadout_count = int(detail.get('telemetry_summary', {}).get('fallback_telemetry_event_count', 0) or 0)
    orphan_card_count = int(detail.get('orphan_card_count', 0) or 0)
    unused_card_count = int(detail.get('card_pool_summary', {}).get('unused_card_count', 0) or 0)
    missing_reports = detail.get('missing_reports', [])
    health_score = 0
    gate_fields = [
        'ready_for_runtime_export',
        'full_sequence_coverage_complete',
        'runtime_export_allowed',
    ]
    if all(bool(validation.get(field, False)) for field in gate_fields):
        health_score += 60
    if bool(validation.get('sequence_balance_pass', False)):
        health_score += 10
    if all_generated_slots_have_reward:
        health_score += 10
    if orphan_card_count == 0:
        health_score += 5
    if bool(validation.get('deck_card_realm_eligibility_valid', False)) and bool(validation.get('no_card_above_player_wujing_in_deck', False)):
        health_score += 5
    if fallback_loadout_count == 0:
        health_score += 5
    if len(missing_reports) <= 1:
        health_score += 5
    health_score = max(0, min(100, health_score - risk_summary['warning_count'] * 2))

    if risk_summary['fail_count'] > 0:
        health_status = 'fail'
    elif risk_summary['warning_count'] > 0:
        health_status = 'warning'
    else:
        health_status = 'pass'
    return {
        'ready_for_runtime_export': bool(validation.get('ready_for_runtime_export', False)),
        'full_sequence_coverage_complete': bool(validation.get('full_sequence_coverage_complete', False)),
        'runtime_export_allowed': bool(validation.get('runtime_export_allowed', False)),
        'sequence_balance_pass': bool(validation.get('sequence_balance_pass', False)),
        'all_generated_slots_have_reward': all_generated_slots_have_reward,
        'fallback_loadout_count': fallback_loadout_count,
        'deck_card_realm_eligibility_valid': bool(validation.get('deck_card_realm_eligibility_valid', False)),
        'no_card_above_player_wujing_in_deck': bool(validation.get('no_card_above_player_wujing_in_deck', False)),
        'orphan_card_count': orphan_card_count,
        'unused_card_count': unused_card_count,
        'missing_reports': missing_reports,
        'health_score': health_score,
        'health_status': health_status,
    }


def build_compare_row(pack_review: dict[str, Any]) -> dict[str, Any]:
    encounter_rows = pack_review.get('encounter_review_table', [])
    power_by_tier = defaultdict(list)
    for row in encounter_rows:
        power_by_tier[str(row.get('encounter_tier', 'unknown'))].append(float(row.get('deck_power_score', 0) or 0))
    card_rows = pack_review.get('card_pool_review_table', [])
    telemetry_summary = pack_review.get('telemetry_snapshot_status', {}).get('telemetry_summary', {})
    snapshot_summary = pack_review.get('telemetry_snapshot_status', {}).get('snapshot_summary', {})
    evaluation_summary = pack_review.get('evaluation_summary', {})
    runtime_primitives = sorted({primitive for row in encounter_rows for primitive in row.get('runtime_primitives', [])})
    balance_summary = pack_review.get('balance_release_summary', {})
    balance_delta = balance_summary.get('source_vs_balanced_delta', {}) if isinstance(balance_summary, dict) else {}
    return {
        'mechanic_profile_id': pack_review['pack_identity']['mechanic_profile_id'],
        'content_pack_id': pack_review['pack_identity']['content_pack_id'],
        'sequence_template_id': str(pack_review['pack_identity'].get('sequence_template_id', '')),
        'template_display_name': str(pack_review['pack_identity'].get('template_display_name', pack_review['pack_identity'].get('sequence_template_id', ''))),
        'template_usage_recommendation': str(pack_review['pack_identity'].get('template_usage_recommendation', '')),
        'build_variant': str(pack_review['pack_identity'].get('build_variant', '')),
        'matrix_slot': bool(pack_review['pack_identity'].get('matrix_slot', False)),
        'matrix_build_variant': str(pack_review['pack_identity'].get('matrix_build_variant', '')),
        'matrix_strategy_tag': str(pack_review['pack_identity'].get('matrix_strategy_tag', '')),
        'stage_counts': pack_review['pack_identity'].get('stage_counts', {}),
        'template_mechanic_pack_binding_valid': bool(pack_review['pack_identity'].get('template_mechanic_pack_binding_valid', False)),
        'is_active': bool(pack_review['pack_identity']['is_active_pack']),
        'health_status': pack_review['health_summary']['health_status'],
        'health_score': pack_review['health_summary']['health_score'],
        'formal_encounter_total_count': len(encounter_rows),
        'card_count': len(card_rows),
        'used_card_count': sum(1 for row in card_rows if not row.get('is_unused')),
        'unused_card_count': sum(1 for row in card_rows if row.get('is_unused')),
        'deck_count': len(pack_review.get('deck_review_table', [])),
        'reward_count': len(pack_review.get('reward_review_table', [])),
        'sequence_balance_pass': bool(pack_review['health_summary']['sequence_balance_pass']),
        'average_deck_power': round(avg([row.get('deck_power_score', 0) for row in encounter_rows]), 2),
        'max_wujing': max([int(row.get('player_wujing_cap', 0) or 0) for row in encounter_rows] or [0]),
        'early_avg_power': round(avg(power_by_tier.get('early', [])), 2),
        'mid_avg_power': round(avg(power_by_tier.get('mid', [])), 2),
        'late_avg_power': round(avg(power_by_tier.get('late', [])), 2),
        'boss_avg_power': round(avg(power_by_tier.get('boss', [])), 2),
        'runtime_primitives': runtime_primitives,
        'opening_pressure_applied_count': sum(1 for row in encounter_rows if row.get('opening_pressure_summary', {}).get('present')),
        'telemetry_event_count': int(telemetry_summary.get('telemetry_event_count', 0) or 0),
        'snapshot_ready': bool(snapshot_summary.get('snapshot_ready', False)),
        'review_status': pack_review.get('review_status', 'pending'),
        'release_status': pack_review.get('release_status', 'draft'),
        'frozen': bool(pack_review.get('frozen', False)),
        'release_candidate': bool(pack_review.get('release_candidate', False)),
        'archived': bool(pack_review.get('archived', False)),
        'llm_candidate_source': bool(pack_review.get('llm_candidate_source', False)),
        'deterministic_fill_used': bool(pack_review.get('deterministic_fill_used', False)),
        'risk_count': pack_review['risk_summary']['risk_count'],
        'fail_count': pack_review['risk_summary']['fail_count'],
        'warning_count': pack_review['risk_summary']['warning_count'],
        'evaluated': bool(evaluation_summary.get('evaluated', False)),
        'evaluation_event_count': int(evaluation_summary.get('evaluation_event_count', 0) or 0),
        'win_rate': float(evaluation_summary.get('win_rate', 0) or 0),
        'avg_turn_count': float(evaluation_summary.get('avg_turn_count', 0) or 0),
        'avg_player_hp_end': float(evaluation_summary.get('avg_player_hp_end', 0) or 0),
        'mechanic_trigger_rate': float(evaluation_summary.get('runtime_primitive_trigger_rate', 0) or 0),
        'stage_metrics': evaluation_summary.get('stage_metrics', {}),
        'actionability_score': int(evaluation_summary.get('actionability_score', 0) or 0),
        'needs_rebuild': bool(evaluation_summary.get('needs_rebuild', False)),
        'is_balance_release': bool(balance_summary.get('balance_release', False)),
        'source_pack_id': str(balance_summary.get('source_pack_id', '')),
        'win_rate_delta_from_source': float(balance_delta.get('win_rate_delta_from_source', 0) or 0),
        'too_hard_delta_from_source': int(balance_delta.get('too_hard_delta_from_source', 0) or 0),
        'avg_turn_delta_from_source': float(balance_delta.get('avg_turn_delta_from_source', 0) or 0),
        'player_hp_delta_from_source': float(balance_delta.get('player_hp_delta_from_source', 0) or 0),
        'playable_balance_gate_pass': bool(balance_summary.get('playable_balance_gate_pass', False)),
        'template_release_strategy': pack_review.get('template_release_strategy', {}),
        'needs_balance_before_release': bool(pack_review.get('needs_balance_before_release', False)),
        'ready_for_candidate_review': bool(pack_review.get('ready_for_candidate_review', False)),
    }


def build_compare_matrix(index_payload: dict[str, Any], rows: list[dict[str, Any]]) -> dict[str, Any]:
    sorted_by_health = sorted(rows, key=lambda item: (health_rank(item['health_status']), -item['health_score'], item['risk_count'], item['content_pack_id']))
    sorted_by_power = sorted(rows, key=lambda item: (-item['average_deck_power'], item['content_pack_id']))
    strongest = sorted_by_power[0] if sorted_by_power else {}
    weakest = sorted(rows, key=lambda item: (item['average_deck_power'], item['content_pack_id']))[0] if rows else {}
    risky = sorted(rows, key=lambda item: (-item['fail_count'], -item['warning_count'], -item['risk_count'], item['content_pack_id']))[0] if rows else {}
    healthiest = sorted_by_health[0] if sorted_by_health else {}
    active_pack = next((row for row in rows if row.get('is_active')), None)
    active_rank = next((idx + 1 for idx, row in enumerate(sorted_by_health) if active_pack and row['content_pack_id'] == active_pack['content_pack_id'] and row['mechanic_profile_id'] == active_pack['mechanic_profile_id']), None)
    return {
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'pack_count': len(rows),
        'real_mechanic_profile_count': len({row['mechanic_profile_id'] for row in rows}),
        'runtime_primitive_types': sorted({primitive for row in rows for primitive in row.get('runtime_primitives', [])}),
        'distinct_mechanic_count': len({row['mechanic_profile_id'] for row in rows}),
        'mechanic_density_by_pack': {
            f"{row['mechanic_profile_id']}::{row['content_pack_id']}": round(avg([
                float(value)
                for value in (
                    row.get('stage_metrics', {}).get('early_stage_event_count'),
                    row.get('stage_metrics', {}).get('mid_stage_event_count'),
                    row.get('stage_metrics', {}).get('late_stage_event_count'),
                    row.get('stage_metrics', {}).get('boss_stage_event_count'),
                )
                if value is not None
            ]), 2)
            for row in rows
        },
        'mechanic_runtime_observable': {
            f"{row['mechanic_profile_id']}::{row['content_pack_id']}": bool(row.get('evaluated', False) and row.get('evaluation_event_count', 0) > 0)
            for row in rows
        },
        'max_wujing_by_pack': {
            f"{row['mechanic_profile_id']}::{row['content_pack_id']}": int(row.get('max_wujing', 0) or 0)
            for row in rows
        },
        'dual_weapon_enabled_by_pack': {
            f"{row['mechanic_profile_id']}::{row['content_pack_id']}": 'dual_weapon' in row.get('runtime_primitives', [])
            for row in rows
        },
        'clue_pressure_enabled_by_pack': {
            f"{row['mechanic_profile_id']}::{row['content_pack_id']}": 'clue_pressure' in row.get('runtime_primitives', [])
            for row in rows
        },
        'packs': rows,
        'strongest_pack_by_avg_power': pack_ref(strongest),
        'most_risky_pack': pack_ref(risky),
        'active_pack_rank_by_health': active_rank,
        'packs_with_runtime_primitives': [pack_ref(row) for row in rows if row.get('runtime_primitives')],
        'packs_with_llm_candidate_source': [pack_ref(row) for row in rows if row.get('llm_candidate_source') or 'llm_candidate' in row.get('mechanic_profile_id', '') or 'llm_candidate' in row.get('content_pack_id', '')],
        'healthiest_pack': pack_ref(healthiest),
        'weakest_pack_by_avg_power': pack_ref(weakest),
    }


def summarize_risks(risks: list[dict[str, Any]]) -> dict[str, Any]:
    risks_by_type = Counter(risk['risk_type'] for risk in risks)
    risks_by_encounter = Counter(risk['formal_encounter_id'] for risk in risks if risk.get('formal_encounter_id'))
    risks_by_card = Counter(risk['card_id'] for risk in risks if risk.get('card_id'))
    risks_by_deck = Counter(risk['deck_id'] for risk in risks if risk.get('deck_id'))
    sorted_risks = sorted(risks, key=lambda item: (SEVERITY_WEIGHT[item['severity']], item['risk_type'], item.get('formal_encounter_id', ''), item.get('deck_id', ''), item.get('card_id', '')))
    return {
        'risk_count': len(risks),
        'fail_count': sum(1 for risk in risks if risk['severity'] == 'fail'),
        'warning_count': sum(1 for risk in risks if risk['severity'] == 'warning'),
        'info_count': sum(1 for risk in risks if risk['severity'] == 'info'),
        'risks_by_type': dict(risks_by_type),
        'risks_by_encounter': dict(risks_by_encounter),
        'risks_by_card': dict(risks_by_card),
        'risks_by_deck': dict(risks_by_deck),
        'top_risks': sorted_risks[:12],
    }


def build_filter_options(
    encounter_rows: list[dict[str, Any]],
    card_rows: list[dict[str, Any]],
    deck_rows: list[dict[str, Any]],
    reward_rows: list[dict[str, Any]],
    risks: list[dict[str, Any]],
) -> dict[str, Any]:
    return {
        'encounter_tiers': sorted({row.get('encounter_tier', '') for row in encounter_rows if row.get('encounter_tier')}),
        'encounter_kinds': sorted({row.get('encounter_kind', '') for row in encounter_rows if row.get('encounter_kind')}),
        'weapon_styles': sorted({row.get('weapon_style', '') for row in card_rows if row.get('weapon_style')}),
        'card_types': sorted({row.get('card_type', '') for row in card_rows if row.get('card_type')}),
        'difficulty_tiers': sorted({row.get('difficulty_tier', '') for row in card_rows if row.get('difficulty_tier')} | {row.get('difficulty_tier', '') for row in deck_rows if row.get('difficulty_tier')}),
        'reward_tiers': sorted({row.get('reward_tier', '') for row in reward_rows if row.get('reward_tier')}),
        'runtime_primitives': sorted({primitive for row in encounter_rows for primitive in row.get('runtime_primitives', [])}),
        'risk_types': sorted({risk.get('risk_type', '') for risk in risks if risk.get('risk_type')}),
        'deck_archetypes': sorted({row.get('deck_archetype', '') for row in deck_rows if row.get('deck_archetype')}),
    }


def build_encounter_design_card(encounter_row: dict[str, Any], deck_row: dict[str, Any], reward_rows: list[dict[str, Any]]) -> dict[str, Any]:
    cards = encounter_row.get('deck_cards', [])
    reward_row = next((row for row in reward_rows if row.get('reward_plan_id') == encounter_row.get('reward_plan_id')), {})
    pressure_cards = pick_cards(cards, {'pressure', 'attack'})
    defense_cards = pick_cards(cards, {'defense', 'gain_block'})
    break_cards = pick_cards(cards, {'break_momentum', 'break'})
    high_power_cards = [card.get('name', card.get('card_id', '')) for card in sorted(cards, key=lambda item: -float(item.get('power_score', 0) or 0))[:3]]
    risk_flags = encounter_row.get('risk_flags', [])
    progression_notes = f"目标 power {encounter_row.get('target_power_min')} - {encounter_row.get('target_power_max')}，当前 {encounter_row.get('deck_power_score')}。"
    return {
        'title': f"#{encounter_row.get('sequence_position')} {encounter_row.get('formal_encounter_id')}",
        'formal_encounter_id': encounter_row.get('formal_encounter_id'),
        'design_role': encounter_row.get('encounter_kind') or 'formal',
        'enemy_role': encounter_row.get('enemy_role'),
        'pressure_summary': encounter_row.get('opening_pressure_summary'),
        'deck_archetype': deck_row.get('deck_archetype', 'generic_mixed'),
        'core_cards': [card.get('name', card.get('card_id', '')) for card in cards[:3]],
        'high_pressure_cards': pressure_cards or high_power_cards,
        'defense_cards': defense_cards,
        'break_cards': break_cards,
        'reward_summary': reward_row.get('reward_items_text', '-'),
        'progression_notes': progression_notes,
        'realm_notes': f"玩家武境上限 {encounter_row.get('player_wujing_cap')}，最高要求 武境{encounter_row.get('max_required_wujing')} / 收式{encounter_row.get('max_closing_form_tier')}。",
        'risk_notes': risk_flags,
        'suggested_action': 'needs_balance_adjustment' if risk_flags else 'ready_for_review',
    }


def build_pack_review_markdown(pack_review: dict[str, Any]) -> str:
    identity = pack_review['pack_identity']
    health = pack_review['health_summary']
    risk = pack_review['risk_summary']
    balance = pack_review.get('balance_release_summary', {})
    lines = [
        f"# Pack 审核表：{identity['mechanic_profile_id']} / {identity['content_pack_id']}",
        '',
        '## 包基本信息',
        f"- active: {'是' if identity['is_active_pack'] else '否'}",
        f"- pack_storage_mode: `{identity['pack_storage_mode']}`",
        f"- runtime_manifest_path: `{identity['runtime_manifest_path']}`",
        f"- target_sequence_id: `{identity['target_sequence_id']}`",
        f"- replacement_mode: `{identity['replacement_mode']}`",
        '',
        '## 健康状态',
        f"- health_status: `{health['health_status']}`",
        f"- health_score: `{health['health_score']}`",
        f"- ready_for_runtime_export: `{health['ready_for_runtime_export']}`",
        f"- sequence_balance_pass: `{health['sequence_balance_pass']}`",
        f"- unused_card_count: `{health['unused_card_count']}`",
        f"- orphan_card_count: `{health['orphan_card_count']}`",
        '',
        '## Balance Release',
        f"- balance_release: `{bool(balance.get('balance_release', False))}`",
        f"- source_pack_id: `{balance.get('source_pack_id', '-') or '-'}`",
        f"- playable_balance_gate_pass: `{bool(balance.get('playable_balance_gate_pass', False))}`",
        '',
        '## 全序列节奏',
    ]
    for row in pack_review.get('run_pacing_view', []):
        lines.append(f"- #{row['sequence_position']} `{row['formal_encounter_id']}` | tier={row['encounter_tiers'] if 'encounter_tiers' in row else row['encounter_tier']} | kind={row['encounter_kind']} | power={row['deck_power_score']} | reward={row['reward_tier']} | risk={','.join(row['risk_flags']) or '-'}")
    lines.extend([
        '',
        '## Risk Board',
        f"- risk_count: `{risk['risk_count']}`",
        f"- fail_count: `{risk['fail_count']}`",
        f"- warning_count: `{risk['warning_count']}`",
        f"- info_count: `{risk['info_count']}`",
    ])
    for item in risk.get('top_risks', []):
        lines.append(f"- [{item['severity']}] {item['risk_type']} | {item['message']} | action={item['suggested_action']}")
    return '\n'.join(lines) + '\n'


def build_review_report_markdown(pack_review: dict[str, Any]) -> str:
    identity = pack_review['pack_identity']
    health = pack_review['health_summary']
    risk = pack_review['risk_summary']
    telemetry = pack_review.get('telemetry_snapshot_status', {})
    balance = pack_review.get('balance_release_summary', {})
    deck_rows = pack_review.get('deck_review_table', [])
    reward_rows = pack_review.get('reward_review_table', [])
    card_rows = pack_review.get('card_pool_review_table', [])
    lines = [
        f"# AIGC Battle 审核报告：{identity['mechanic_profile_id']} / {identity['content_pack_id']}",
        '',
        '## 1. 包基本信息',
        f"- active: {'是' if identity['is_active_pack'] else '否'}",
        f"- pack_storage_mode: `{identity['pack_storage_mode']}`",
        f"- target_sequence_id: `{identity['target_sequence_id']}`",
        f"- replacement_mode: `{identity['replacement_mode']}`",
        '',
        '## 2. 机制摘要',
        f"- runtime_manifest_path: `{identity['runtime_manifest_path']}`",
        f"- runtime primitives: {', '.join(pack_review['visual_filter_options'].get('runtime_primitives', [])) or '-'}",
        '',
        '## 2.5 Balance Release',
        f"- balance_release: `{bool(balance.get('balance_release', False))}`",
        f"- source_pack_id: `{balance.get('source_pack_id', '-') or '-'}`",
        f"- playable_balance_gate_pass: `{bool(balance.get('playable_balance_gate_pass', False))}`",
        '',
        '## 3. 健康状态',
        f"- health_status: `{health['health_status']}`",
        f"- health_score: `{health['health_score']}`",
        f"- ready_for_runtime_export: `{health['ready_for_runtime_export']}`",
        f"- full_sequence_coverage_complete: `{health['full_sequence_coverage_complete']}`",
        f"- runtime_export_allowed: `{health['runtime_export_allowed']}`",
        '',
        '## 4. 全序列节奏',
    ]
    for row in pack_review.get('run_pacing_view', []):
        lines.append(f"- #{row['sequence_position']} `{row['formal_encounter_id']}` | {row['encounter_tier']}/{row['encounter_kind']} | power={row['deck_power_score']} | reward={row['reward_tier']} | wujing={row['player_wujing_cap']}")
    lines.extend(['', '## 5. 战斗列表'])
    for row in pack_review.get('encounter_review_table', []):
        lines.append(f"- `{row['formal_encounter_id']}` -> deck=`{row['generated_deck_id']}` reward=`{row['reward_plan_id']}` risk={','.join(row['risk_flags']) or '-'}")
    lines.extend(['', '## 6. 单场战斗设计卡摘要'])
    for row in pack_review.get('encounter_design_cards', []):
        lines.append(f"- `{row['title']}` | archetype=`{row['deck_archetype']}` | action=`{row['suggested_action']}`")
    lines.extend([
        '',
        '## 7. 卡池摘要',
        f"- card_count: `{len(card_rows)}`",
        f"- unused_card_count: `{sum(1 for row in card_rows if row.get('is_unused'))}`",
        f"- high_power_card_count: `{sum(1 for row in card_rows if row.get('is_high_power'))}`",
        '',
        '## 8. Deck 行为摘要',
    ])
    for row in deck_rows:
        lines.append(f"- `{row['deck_id']}` | archetype=`{row['deck_archetype']}` | A={row['aggression_score']} D={row['defense_score']} M={row['momentum_score']} B={row['break_score']}")
    lines.extend([
        '',
        '## 9. Reward 成长摘要',
    ])
    for row in reward_rows:
        lines.append(f"- `{row['reward_plan_id']}` | tier=`{row['reward_tier']}` | items={row['reward_items_text']}")
    lines.extend([
        '',
        '## 10. Risk Board',
        f"- risk_count: `{risk['risk_count']}`",
        f"- fail_count: `{risk['fail_count']}`",
        f"- warning_count: `{risk['warning_count']}`",
    ])
    for item in risk.get('top_risks', []):
        lines.append(f"- [{item['severity']}] {item['message']} | action=`{item['suggested_action']}`")
    lines.extend([
        '',
        '## 11. Telemetry / Snapshot 状态',
        f"- telemetry: `{bool(telemetry.get('telemetry_summary'))}`",
        f"- snapshot: `{bool(telemetry.get('snapshot_summary'))}`",
        f"- missing_reports: {', '.join(telemetry.get('missing_reports', [])) or '-'}",
        '',
        '## 12. 建议动作',
        f"- `{pack_review.get('recommended_action', 'ready_for_review')}`",
    ])
    return '\n'.join(lines) + '\n'


def build_workspace_markdown(workspace: dict[str, Any]) -> str:
    risk = workspace['global_risk_summary']
    lines = [
        '# AIGC Battle Review Workspace',
        '',
        f"- active_profile_id: `{workspace['active_profile_id']}`",
        f"- active_content_pack_id: `{workspace['active_content_pack_id']}`",
        f"- profile_count: `{workspace['profile_count']}`",
        f"- content_pack_count: `{workspace['content_pack_count']}`",
        f"- active_pack_review_path: `{workspace['active_pack_review_path']}`",
        '',
        '## 全局风险摘要',
        f"- risk_count: `{risk['risk_count']}`",
        f"- fail_count: `{risk['fail_count']}`",
        f"- warning_count: `{risk['warning_count']}`",
        '',
        '## 推荐审核顺序',
    ]
    for item in workspace.get('recommended_review_order', []):
        lines.append(f"- `{item['mechanic_profile_id']}` / `{item['content_pack_id']}` | status=`{item['health_status']}` | score=`{item['health_score']}` | risk=`{item['risk_count']}`")
    return '\n'.join(lines) + '\n'


def build_compare_matrix_markdown(compare_matrix: dict[str, Any]) -> str:
    lines = [
        '# Pack 对比矩阵',
        '',
        f"- pack_count: `{compare_matrix['pack_count']}`",
        f"- strongest_pack_by_avg_power: `{compare_matrix['strongest_pack_by_avg_power']}`",
        f"- most_risky_pack: `{compare_matrix['most_risky_pack']}`",
        f"- healthiest_pack: `{compare_matrix['healthiest_pack']}`",
        f"- weakest_pack_by_avg_power: `{compare_matrix['weakest_pack_by_avg_power']}`",
        '',
        '| Active | Profile | Pack | Health | Score | Avg Power | Eval | Win | Avg Turn | Trigger | Actionability | Rebuild | Balance Release | Win Delta | Runtime Primitives |',
        '| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | --- |',
    ]
    for row in compare_matrix.get('packs', []):
        lines.append(
            f"| {'YES' if row['is_active'] else ''} | `{row['mechanic_profile_id']}` | `{row['content_pack_id']}` | `{row['health_status']}` | {row['health_score']} | {row['average_deck_power']} | {row.get('evaluation_event_count', 0)} | {row.get('win_rate', 0)} | {row.get('avg_turn_count', 0)} | {row.get('mechanic_trigger_rate', 0)} | {row.get('actionability_score', 0)} | {'YES' if row.get('needs_rebuild') else ''} | {'YES' if row.get('is_balance_release') else ''} | {row.get('win_rate_delta_from_source', 0)} | `{','.join(row['runtime_primitives']) or '-'}` |"
        )
    return '\n'.join(lines) + '\n'


def score_deck(cards: list[dict[str, Any]]) -> dict[str, Any]:
    totals = {'aggression_score': 0.0, 'defense_score': 0.0, 'momentum_score': 0.0, 'break_score': 0.0}
    style_counts = Counter(str(card.get('weapon_style', 'generic')) for card in cards)
    for card in cards:
        power = float(card.get('power_score', 0) or 0)
        for effect in card.get('effects', []):
            effect_type = str(effect.get('type', ''))
            value = float(effect.get('value', 0) or 0)
            weight = max(value, power * 0.5, 1.0)
            if effect_type in {'damage', 'attack'}:
                totals['aggression_score'] += weight
            elif effect_type in {'gain_block', 'defense'}:
                totals['defense_score'] += weight
            elif effect_type in {'gain_momentum'}:
                totals['momentum_score'] += weight
            elif effect_type in {'break_momentum'}:
                totals['break_score'] += weight
        if str(card.get('card_type', '')) == 'attack':
            totals['aggression_score'] += power * 0.4
        if str(card.get('card_type', '')) == 'defense':
            totals['defense_score'] += power * 0.4
    top_style = style_counts.most_common(1)[0][0] if style_counts else 'generic'
    primary = max(totals, key=totals.get) if cards else 'aggression_score'
    if not cards:
        archetype = 'generic_mixed'
    elif totals['aggression_score'] >= totals['defense_score'] * 1.3 and top_style == 'blade':
        archetype = 'blade_burst'
    elif totals['aggression_score'] >= totals['defense_score'] * 1.15 and top_style == 'spearman':
        archetype = 'spear_pressure'
    elif totals['defense_score'] > totals['aggression_score'] * 1.2:
        archetype = 'defensive_delay'
    elif totals['momentum_score'] >= max(totals['aggression_score'], totals['defense_score'], totals['break_score']):
        archetype = 'momentum_builder'
    elif totals['break_score'] >= max(totals['aggression_score'], totals['defense_score'], totals['momentum_score']):
        archetype = 'momentum_breaker'
    elif top_style == 'generic':
        archetype = 'steady_guard' if primary == 'defense_score' else 'generic_mixed'
    else:
        archetype = 'boss_mixed_pressure' if max(totals.values(), default=0) >= 18 else 'generic_mixed'
    pressure_profile = primary.replace('_score', '')
    return {
        'aggression_score': round(totals['aggression_score'], 2),
        'defense_score': round(totals['defense_score'], 2),
        'momentum_score': round(totals['momentum_score'], 2),
        'break_score': round(totals['break_score'], 2),
        'pressure_profile': pressure_profile,
        'deck_archetype': archetype,
    }


def recommend_action(health: dict[str, Any], risk: dict[str, Any], telemetry: dict[str, Any], snapshot: dict[str, Any]) -> str:
    if risk['fail_count'] > 0:
        if not health['runtime_export_allowed'] or not health['ready_for_runtime_export']:
            return 'blocked_by_runtime'
        if not health['full_sequence_coverage_complete'] or not health['deck_card_realm_eligibility_valid']:
            return 'blocked_by_validation'
        return 'needs_rebuild'
    if not telemetry or not snapshot:
        return 'needs_real_telemetry'
    if risk['warning_count'] > 0:
        return 'needs_balance_adjustment'
    if health['health_status'] == 'pass':
        return 'safe_to_test' if health['health_score'] < 100 else 'ready_for_review'
    return 'ready_for_review'


def pack_review_json_path(profile_id: str, content_pack_id: str) -> Path:
    return REVIEW_DIR / f'pack_review_{profile_id}__{content_pack_id}.json'


def pack_review_md_path(profile_id: str, content_pack_id: str) -> Path:
    return REVIEW_DIR / f'pack_review_{profile_id}__{content_pack_id}.md'


def review_report_md_path(profile_id: str, content_pack_id: str) -> Path:
    return REVIEW_DIR / f'review_report_{profile_id}__{content_pack_id}.md'


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def avg(values: list[Any]) -> float:
    nums = [float(value or 0) for value in values]
    return sum(nums) / len(nums) if nums else 0.0


def tier_rank(value: str) -> int:
    return {'basic': 0, 'early': 0, 'mid': 1, 'standard': 1, 'late': 2, 'advanced': 2, 'elite': 3, 'boss': 4}.get(str(value), 0)


def health_rank(value: str) -> int:
    return {'pass': 0, 'warning': 1, 'fail': 2}.get(value, 3)


def compute_high_power_threshold(cards: list[dict[str, Any]]) -> float:
    scores = sorted(float(card.get('power_score', 0) or 0) for card in cards)
    if not scores:
        return 0
    pivot = scores[max(0, math.ceil(len(scores) * 0.8) - 1)]
    return max(6.0, pivot)


def safe_int(value: Any) -> int:
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def format_effect(effect: dict[str, Any]) -> str:
    effect_type = str(effect.get('type', 'unknown'))
    value = effect.get('value')
    return f'{effect_type}:{value}' if value is not None else effect_type


def format_reward_items(items: list[dict[str, Any]]) -> str:
    if not items:
        return '-'
    return ', '.join(f"{item.get('item_id', '')}x{item.get('quantity', 1)}" for item in items)


def summarize_opening_pressure(opening_pressure: dict[str, Any] | None) -> dict[str, Any]:
    if not opening_pressure:
        return {'present': False, 'text': '-', 'value': 0}
    momentum = safe_int(opening_pressure.get('enemy_start_momentum_bonus'))
    block = safe_int(opening_pressure.get('enemy_start_block_bonus'))
    value = momentum + block
    return {
        'present': True,
        'text': f"动量+{momentum} / 格挡+{block}",
        'value': value,
        'source': str(opening_pressure.get('source', '')),
    }


def extract_opening_pressure_value(summary: dict[str, Any]) -> int:
    return safe_int(summary.get('value')) if isinstance(summary, dict) else 0


def pick_cards(cards: list[dict[str, Any]], keywords: set[str], limit: int = 3) -> list[str]:
    selected: list[str] = []
    for card in cards:
        tags = {str(tag) for tag in card.get('tags', [])}
        effect_types = {str(effect.get('type', '')) for effect in card.get('effects', [])}
        if tags & keywords or effect_types & keywords or str(card.get('card_type', '')) in keywords:
            selected.append(str(card.get('name', card.get('card_id', ''))))
        if len(selected) >= limit:
            break
    return selected


def risk_item(
    severity: str,
    risk_type: str,
    message: str,
    profile_id: str,
    content_pack_id: str,
    formal_encounter_id: str = '',
    deck_id: str = '',
    card_id: str = '',
    suggested_action: str = 'ready_for_review',
) -> dict[str, Any]:
    return {
        'severity': severity,
        'risk_type': risk_type,
        'message': message,
        'profile_id': profile_id,
        'content_pack_id': content_pack_id,
        'formal_encounter_id': formal_encounter_id,
        'deck_id': deck_id,
        'card_id': card_id,
        'suggested_action': suggested_action,
    }


def empty_filter_options() -> dict[str, Any]:
    return {
        'encounter_tiers': [],
        'encounter_kinds': [],
        'weapon_styles': [],
        'card_types': [],
        'difficulty_tiers': [],
        'reward_tiers': [],
        'runtime_primitives': [],
        'risk_types': [],
        'deck_archetypes': [],
    }


def pack_ref(row: dict[str, Any]) -> str:
    if not row:
        return ''
    return f"{row.get('mechanic_profile_id', '')}::{row.get('content_pack_id', '')}"


def load_review_notes(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = REVIEW_NOTES_DIR / f'{profile_id}__{content_pack_id}.json'
    if path.exists():
        return json.loads(path.read_text(encoding='utf-8'))
    return default_review_notes(profile_id, content_pack_id)


def default_review_notes(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    return {
        'mechanic_profile_id': profile_id,
        'content_pack_id': content_pack_id,
        'review_status': 'pending',
        'reviewer': '',
        'review_time': '',
        'summary': '',
        'recommended_action': 'safe_to_test',
        'global_notes': '',
        'encounter_notes': {},
        'card_notes': {},
        'deck_notes': {},
        'reward_notes': {},
        'risk_decisions': {},
        'last_updated_at': '',
    }


def load_optional_json(relative_path: str) -> dict[str, Any]:
    if not relative_path:
        return {}
    path = ROOT / relative_path
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding='utf-8'))


def build_active_history_summary(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    rows = switch_lib.read_active_history() if ACTIVE_HISTORY_PATH.exists() else []
    related = [row for row in rows if row.get('next_profile_id') == profile_id and row.get('next_content_pack_id') == content_pack_id]
    latest = related[-1] if related else {}
    return {
        'switch_count': len(related),
        'latest_switch': latest,
    }


def build_factory_log_summary(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    if not FACTORY_LOG_DIR.exists():
        return {'log_count': 0, 'latest_log_path': '', 'latest_status': ''}
    candidates = sorted(
        (
            path for path in FACTORY_LOG_DIR.glob('*.json')
            if f'_{profile_id}_' in path.name and (f'_{content_pack_id}.json' in path.name or content_pack_id in path.read_text(encoding='utf-8', errors='ignore'))
        ),
        key=lambda path: path.stat().st_mtime,
    )
    latest = candidates[-1] if candidates else None
    latest_payload = json.loads(latest.read_text(encoding='utf-8')) if latest else {}
    return {
        'log_count': len(candidates),
        'latest_log_path': to_relative(latest) if latest else '',
        'latest_status': latest_payload.get('status', ''),
    }


if __name__ == '__main__':
    raise SystemExit(main())
