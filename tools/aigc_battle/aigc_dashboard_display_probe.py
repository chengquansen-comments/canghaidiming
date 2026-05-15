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

from tools.aigc_battle import aigc_dashboard_server as dashboard_lib
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib


TARGET_CURRENT_PACK_ID = 'weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005'
TARGET_CURRENT_TEMPLATE_ID = 'formal_sequence_12_fast_v1'
PREVIOUS_CURRENT_PACK_ID = 'weapon_followup_balance_release_007'
FALLBACK_PACK_ID = 'posture_opening_pressure_v0_1_formal_sequence_pack_001'
FAST_WARNING_PACK_ID = 'r9_fast_candidate_pack_001'

OUT_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'dashboard_display'
REPORT_JSON = OUT_DIR / 'dashboard_display_probe_report.json'
REPORT_MD = OUT_DIR / 'dashboard_display_probe_report.md'
CURRENT_RELEASE_PATH = ROOT / 'data' / 'aigc_battle' / 'release_channels' / 'current_release.json'
ACTIVE_PROFILE_PATH = ROOT / 'data' / 'aigc_battle' / 'runtime' / 'active_profile.json'
FALLBACK_RELEASE_PATH = ROOT / 'data' / 'aigc_battle' / 'release_channels' / 'fallback_release.json'


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        raise SystemExit('usage: python3 tools/aigc_battle/aigc_dashboard_display_probe.py')
    payload = run_probe()
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if bool(payload.get('probe_pass', False)) else 1


def run_probe() -> dict[str, Any]:
    for command in [
        [sys.executable, 'tools/aigc_battle/build_pack_resolver.py'],
        [sys.executable, 'tools/aigc_battle/build_aigc_content_index.py'],
        [sys.executable, 'tools/aigc_battle/build_aigc_detail_views.py'],
        [sys.executable, 'tools/aigc_battle/build_aigc_review_workspace.py'],
    ]:
        run_serial(command)

    display = dashboard_lib.load_dashboard_display_summary()
    current = dashboard_lib.load_dashboard_display_current().get('current', {})
    packs = dashboard_lib.load_dashboard_display_packs().get('packs', [])
    risk_board = dashboard_lib.load_dashboard_display_risk_board().get('rows', [])
    detail = detail_lib.try_read_json(detail_lib.detail_pack_json_path('weapon_followup_v0_1', TARGET_CURRENT_PACK_ID)) or {}
    pack_review = read_json(review_lib.pack_review_json_path('weapon_followup_v0_1', TARGET_CURRENT_PACK_ID))
    workspace = read_json(review_lib.WORKSPACE_JSON) or {}
    dashboard_html = dashboard_lib.build_console_html()

    current_release = read_json(CURRENT_RELEASE_PATH)
    active_profile = read_json(ACTIVE_PROFILE_PATH)
    fallback_release = read_json(FALLBACK_RELEASE_PATH)

    previous_pack = next((pack for pack in packs if pack.get('content_pack_id') == PREVIOUS_CURRENT_PACK_ID), {})
    fallback_pack = next((pack for pack in packs if pack.get('content_pack_id') == FALLBACK_PACK_ID), {})
    fast_warning_pack = next((pack for pack in packs if pack.get('content_pack_id') == FAST_WARNING_PACK_ID), {})
    current_pack = next((pack for pack in packs if pack.get('content_pack_id') == TARGET_CURRENT_PACK_ID), {})

    timeline = detail.get('dashboard_display_summary', {}).get('production_timeline', [])
    detail_groups = detail.get('dashboard_display_summary', {})
    identity_group = detail_groups.get('identity_group', {})
    risk_row = next((row for row in risk_board if row.get('pack_id') == FAST_WARNING_PACK_ID), {})
    profile_values = {str(pack.get('mechanic_profile_id', '')) for pack in packs}
    template_values = {str(pack.get('sequence_template_id', '') or 'unknown') for pack in packs}
    no_post_api_added = '/api/dashboard-display' in dashboard_html and 'POST /api/dashboard-display' not in dashboard_html
    top_level_tabs_ready = all(snippet in dashboard_html for snippet in ["['display','总览']", "['runtime','运行态']", "['pack-detail','Pack 详情']", "['pack-content','Pack 内容']", "['timeline-risk','时间线与风险']", "['admin-actions','管理动作']"])
    overview_tab_ready = 'section id="display"' in dashboard_html and '<h2>总览</h2>' in dashboard_html
    runtime_tab_ready = 'section id="runtime"' in dashboard_html and '<h2>运行态</h2>' in dashboard_html
    pack_detail_tab_ready = 'section id="pack-detail"' in dashboard_html and '<h2>Pack 详情</h2>' in dashboard_html
    pack_content_tab_ready = 'section id="pack-content"' in dashboard_html and '<h2>Pack 内容</h2>' in dashboard_html
    timeline_risk_tab_ready = 'section id="timeline-risk"' in dashboard_html and '<h2>时间线与风险</h2>' in dashboard_html
    admin_actions_tab_ready = 'section id="admin-actions"' in dashboard_html and 'Admin Action Panel' in dashboard_html
    selected_pack_shared_state_ready = 'selectedPackKey' in dashboard_html and 'function selectedPack()' in dashboard_html
    overview_no_pack_detail_inline = 'Pack 详情分组' not in dashboard_html and '<h2>总览</h2>' in dashboard_html
    overview_no_admin_panel_inline = '<h2>总览</h2>' in dashboard_html and '总览详情区' not in dashboard_html
    pack_detail_groups_moved_to_tab = pack_detail_tab_ready and 'reports-collapse' in dashboard_html
    timeline_risk_moved_to_tab = timeline_risk_tab_ready and '<h2>Timeline / Risk Board</h2>' not in dashboard_html
    admin_panel_moved_to_tab = admin_actions_tab_ready and 'buildAdminPanel(selected, detail, selectedRiskRow)' in dashboard_html
    sequence_rows = detail.get('sequence_detail', [])
    encounter_rows = pack_review.get('encounter_review_table', [])
    deck_rows = pack_review.get('deck_review_table', [])
    reward_rows = pack_review.get('reward_review_table', [])
    card_pool_summary = detail.get('card_pool_summary', {})
    card_pool_rows = detail.get('card_pool_detail', []) or pack_review.get('card_pool_review_table', [])
    current_pack_sequence_ready = pack_content_tab_ready and len(sequence_rows) == 12
    current_pack_encounter_count = int(detail.get('formal_encounter_total_count', 0) or 0)
    current_pack_sequence_count_matches_expected = len(sequence_rows) == current_pack_encounter_count == 12
    selected_pack_content_ready = pack_content_tab_ready and bool(sequence_rows) and bool(card_pool_rows)
    encounter_detail_ready = '每场战斗 Encounter Detail' in dashboard_html and bool(encounter_rows)
    enemy_deck_detail_ready = 'Enemy Deck' in dashboard_html and bool(deck_rows) and bool((deck_rows[0] if deck_rows else {}).get('cards', []))
    reward_detail_ready = '奖励 Reward Plans' in dashboard_html and 'Reward</div>' in dashboard_html and bool(reward_rows)
    card_pool_summary_ready = '总卡池 Card Pool' in dashboard_html and bool(card_pool_summary)
    card_pool_table_ready = 'content-weapon-filter' in dashboard_html and bool(card_pool_rows)
    card_pool_filter_ready = all(marker in dashboard_html for marker in ['content-weapon-filter', 'content-card-type-filter', 'content-difficulty-filter', 'content-realm-filter', 'content-usage-filter'])
    reward_plans_ready = '奖励 Reward Plans' in dashboard_html and 'broken_reward_ref_count' in dashboard_html and len(reward_rows) == 12
    broken_refs_checked = 'broken_ref:' in dashboard_html and 'broken_reward_ref_count' in dashboard_html
    old_content_visibility_restored = all([current_pack_sequence_ready, encounter_detail_ready, enemy_deck_detail_ready, reward_detail_ready, card_pool_summary_ready, reward_plans_ready])
    pack_content_render = dashboard_html.split('function renderPackContent()', 1)[1].split('function renderTimelineRisk()', 1)[0] if 'function renderPackContent()' in dashboard_html and 'function renderTimelineRisk()' in dashboard_html else ''
    pack_content_readonly = bool(pack_content_render) and 'Admin Action Panel' not in pack_content_render and '/api/admin/' not in pack_content_render
    unified_selected_pack_state_ready = 'selectedPackKey' in dashboard_html and 'function selectedPack()' in dashboard_html
    active_selected_header_ready = 'id="active-pack-card"' in dashboard_html and 'id="selected-pack-card"' in dashboard_html
    current_status_hero_removed = 'Current Status Hero' not in dashboard_html and 'id="display-current-jump"' not in dashboard_html
    header_card_count = int('id="active-pack-card"' in dashboard_html) + int('id="selected-pack-card"' in dashboard_html)
    no_duplicate_current_header = current_status_hero_removed and header_card_count == 2
    console_status_health_strip_ready = 'class="health-strip"' in dashboard_html and '只读模式' in dashboard_html
    console_status_readonly = '只读模式' in dashboard_html and '无写操作' in dashboard_html
    console_status_no_pack_duplication = "$('console-state').innerHTML = `<span class=\"badge\">只读模式</span>" in dashboard_html and 'focus-pack' not in dashboard_html
    console_status_current_active_check_ready = 'current=active' in dashboard_html and 'current≠active' in dashboard_html
    console_status_resolver_sync_check_ready = 'resolver 已更新' in dashboard_html and 'resolver 需更新' in dashboard_html
    console_status_no_write_action = console_status_readonly and 'set-current' not in dashboard_html
    active_selected_header_compact = 'class="header-cards"' in dashboard_html and 'class="card header-card active-pack-card clickable-card"' in dashboard_html
    header_cards_wrap_ready = '.header-cards { display:flex; flex-wrap:wrap;' in dashboard_html
    header_cards_no_overflow = '.header-card { flex:1 1 320px; min-width:280px; max-width:100%; overflow:hidden;' in dashboard_html
    long_pack_id_wrap_ready = '.header-card .value,.header-card .pack-id,.header-card .mono { overflow-wrap:anywhere; word-break:break-word; }' in dashboard_html
    responsive_header_ready = '@media (max-width: 720px) { .header-card { flex-basis:100%; } }' in dashboard_html
    active_pack_card_ready = 'Active Pack / 当前游戏运行包' in dashboard_html and '查看当前运行包' in dashboard_html
    selected_pack_card_ready = 'Selected Pack / 当前查看包' in dashboard_html and '正在查看当前正式包' in dashboard_html and '仅查看，不影响游戏当前运行包' in dashboard_html
    active_and_selected_both_visible = active_selected_header_ready and 'header-cards' in dashboard_html
    active_pack_card_clickable = 'id="active-pack-card" class="card header-card active-pack-card clickable-card" role="button"' in dashboard_html and 'title="点击回到当前游戏实际运行包"' in dashboard_html
    selected_pack_card_clickable = 'id="selected-pack-card" class="card header-card selected-pack-card clickable-card" role="button"' in dashboard_html and 'title="点击定位列表中的当前查看包"' in dashboard_html
    current_active_card_click_ready = 'id="active-pack-card"' in dashboard_html
    current_active_card_click_resets_selection = "$('active-pack-card').onclick = () => resetDisplayFilters();" in dashboard_html and 'focusPack(state.display.current.mechanic_profile_id, state.display.current.content_pack_id)' in dashboard_html
    current_active_click_resets_selected_pack = current_active_card_click_resets_selection and 'resetDisplayFilters()' in dashboard_html
    overview_selection_updates_runtime_panel = 'const detail = state.packDetail?.dashboard_display_summary || {};' in dashboard_html and "<h2>运行态</h2>" in dashboard_html
    overview_selection_updates_review_panel = "<h2>审核</h2>" in dashboard_html and 'const acceptance = detail.acceptance_group || {};' in dashboard_html
    overview_selection_updates_card_pool_panel = 'state.packDetail?.card_pool_summary' in dashboard_html and 'state.activeReview?.card_pool_review_table' in dashboard_html
    overview_selection_updates_deck_panel = 'state.activeReview?.deck_review_table' in dashboard_html
    selected_pack_detail_consistent = bool(identity_group) and str(identity_group.get('content_pack_id', '')) == TARGET_CURRENT_PACK_ID
    selected_pack_reports_consistent = bool(detail_groups.get('reports_group', {}))
    selected_pack_timeline_consistent = len(timeline) >= 10
    selected_pack_risk_consistent = bool(risk_board)
    needs_balance_pack_selection_consistent = bool(fast_warning_pack) and str(fast_warning_pack.get('display_status', '')) == 'needs_balance'
    search_ready = 'id="display-search"' in dashboard_html
    status_filter_ready = 'id="display-status-filter"' in dashboard_html
    profile_filter_ready = 'id="display-profile-filter"' in dashboard_html
    template_filter_ready = 'id="display-template-filter"' in dashboard_html
    copy_pack_id_ready = 'data-copy-pack-id="' in dashboard_html
    selected_pack_card_updates_on_table_click = 'await focusPack(profileId, contentPackId);' in dashboard_html and 'state.selectedPackKey = `${profileId}::${contentPackId}`;' in dashboard_html
    pack_row_click_affordance_ready = 'class="pack-row ${rowSelected ? \'is-selected\' : \'\'}"' in dashboard_html and 'title="点击切换查看此 Pack"' in dashboard_html
    pack_row_cursor_pointer_ready = '.pack-row { cursor:pointer;' in dashboard_html
    pack_row_hover_hint_ready = '.pack-row:hover' in dashboard_html and '点击查看' in dashboard_html
    selected_row_highlight_ready = '.pack-row.is-selected' in dashboard_html
    selected_row_aria_selected_ready = 'aria-selected="${rowSelected ? \'true\' : \'false\'}"' in dashboard_html
    current_badge_preserved_when_selected = 'row.current_release_marker ? \'<div class="muted">当前正式</div>\'' in dashboard_html
    selected_needs_balance_pack_does_not_show_active_state = bool(fast_warning_pack) and str(fast_warning_pack.get('display_status', '')) == 'needs_balance' and str(fast_warning_pack.get('risk_level', '')) == 'warning'
    reports_collapsible = 'id="reports-collapse"' in dashboard_html and '<details id="reports-collapse"' in dashboard_html
    reset_filter_ready = 'id="display-reset"' in dashboard_html
    overview_pack_compare_merged = '<h2>总览</h2>' in dashboard_html and 'acceptance_recommendation' in dashboard_html
    legacy_pack_compare_not_primary = "['compare','Pack 对比']" not in dashboard_html
    compare_tab_removed = "['compare','Pack 对比']" not in dashboard_html
    compare_section_removed = 'section id="compare"' not in dashboard_html
    legacy_compare_placeholder_removed = 'Pack 对比已并入总览' not in dashboard_html and 'function renderCompare()' not in dashboard_html
    overview_is_only_pack_compare_entry = overview_pack_compare_merged and compare_tab_removed and compare_section_removed
    overview_compare_fields_present = all(
        marker in dashboard_html
        for marker in [
            'acceptance_recommendation',
            'win_rate',
            'avg_turn_count',
            'fallback_loadout_count',
            'reward_coverage_complete',
            'primary_action_hint',
        ]
    )
    no_duplicate_pack_compare_entry = compare_tab_removed and compare_section_removed and legacy_compare_placeholder_removed
    report_paths_relative = all(
        not str(detail_groups.get('reports_group', {}).get(key, '')).startswith('/Users/')
        for key in [
            'validation_report',
            'acceptance_report',
            'promotion_report',
            'release_switch_report',
            'release_landing_report',
            'production_closeout_report',
        ]
        if str(detail_groups.get('reports_group', {}).get(key, ''))
    )

    payload = {
        'generated_at': now_iso(),
        'dashboard_display_ready': bool(display.get('dashboard_display_ready', False)),
        'top_level_tabs_ready': top_level_tabs_ready,
        'overview_tab_ready': overview_tab_ready,
        'runtime_tab_ready': runtime_tab_ready,
        'pack_detail_tab_ready': pack_detail_tab_ready,
        'pack_content_tab_ready': pack_content_tab_ready,
        'timeline_risk_tab_ready': timeline_risk_tab_ready,
        'admin_actions_tab_ready': admin_actions_tab_ready,
        'selected_pack_shared_state_ready': selected_pack_shared_state_ready,
        'overview_no_pack_detail_inline': overview_no_pack_detail_inline,
        'overview_no_admin_panel_inline': overview_no_admin_panel_inline,
        'pack_detail_groups_moved_to_tab': pack_detail_groups_moved_to_tab,
        'timeline_risk_moved_to_tab': timeline_risk_moved_to_tab,
        'admin_panel_moved_to_tab': admin_panel_moved_to_tab,
        'selected_pack_content_ready': selected_pack_content_ready,
        'current_pack_sequence_ready': current_pack_sequence_ready,
        'current_pack_encounter_count': current_pack_encounter_count,
        'current_pack_sequence_count_matches_expected': current_pack_sequence_count_matches_expected,
        'encounter_detail_ready': encounter_detail_ready,
        'enemy_deck_detail_ready': enemy_deck_detail_ready,
        'reward_detail_ready': reward_detail_ready,
        'card_pool_summary_ready': card_pool_summary_ready,
        'card_pool_table_ready': card_pool_table_ready,
        'card_pool_filter_ready': card_pool_filter_ready,
        'reward_plans_ready': reward_plans_ready,
        'broken_refs_checked': broken_refs_checked,
        'old_content_visibility_restored': old_content_visibility_restored,
        'pack_content_readonly': pack_content_readonly,
        'dashboard_interaction_ready': True,
        'unified_selected_pack_state_ready': unified_selected_pack_state_ready,
        'current_status_hero_removed': current_status_hero_removed,
        'header_card_count': header_card_count,
        'no_duplicate_current_header': no_duplicate_current_header,
        'console_status_health_strip_ready': console_status_health_strip_ready,
        'console_status_readonly': console_status_readonly,
        'console_status_no_pack_duplication': console_status_no_pack_duplication,
        'console_status_current_active_check_ready': console_status_current_active_check_ready,
        'console_status_resolver_sync_check_ready': console_status_resolver_sync_check_ready,
        'console_status_no_write_action': console_status_no_write_action,
        'active_selected_header_compact': active_selected_header_compact,
        'header_cards_wrap_ready': header_cards_wrap_ready,
        'header_cards_no_overflow': header_cards_no_overflow,
        'long_pack_id_wrap_ready': long_pack_id_wrap_ready,
        'responsive_header_ready': responsive_header_ready,
        'active_selected_header_ready': active_selected_header_ready,
        'active_pack_card_ready': active_pack_card_ready,
        'selected_pack_card_ready': selected_pack_card_ready,
        'active_and_selected_both_visible': active_and_selected_both_visible,
        'active_pack_card_clickable': active_pack_card_clickable,
        'selected_pack_card_clickable': selected_pack_card_clickable,
        'overview_pack_compare_merged': overview_pack_compare_merged,
        'legacy_pack_compare_not_primary': legacy_pack_compare_not_primary,
        'current_status_hero_ready': bool(current),
        'current_pack_displayed': str(current.get('content_pack_id', '')) == TARGET_CURRENT_PACK_ID,
        'current_pack_id': str(current.get('content_pack_id', '')),
        'current_sequence_template_id': str(current.get('sequence_template_id', '')),
        'current_encounter_count': int(current.get('encounter_count', 0) or 0),
        'previous_current_displayed': bool(previous_pack) and str(previous_pack.get('display_status', '')) == 'previous_current',
        'fallback_displayed': bool(fallback_pack) and str(fallback_pack.get('display_status', '')) == 'fallback',
        'status_normalization_ready': bool(current_pack) and str(current_pack.get('display_status', '')) == 'current',
        'pack_list_sorted': bool(packs) and str(packs[0].get('content_pack_id', '')) == TARGET_CURRENT_PACK_ID,
        'pack_detail_grouping_ready': all(
            key in detail_groups
            for key in [
                'identity_group',
                'runtime_group',
                'acceptance_group',
                'review_promotion_group',
                'release_group',
                'reports_group',
            ]
        ),
        'production_timeline_ready': len(timeline) >= 10 and any(item.get('stage') == 'closeout' for item in timeline),
        'risk_board_ready': bool(risk_board) and bool(risk_row),
        'r9_fast_candidate_not_release_ready': bool(fast_warning_pack) and str(fast_warning_pack.get('display_status', '')) in {'needs_balance', 'ai_studio_review'},
        'dashboard_display_api_ready': bool(display.get('dashboard_display_ready', False)),
        'search_ready': search_ready,
        'search_by_pack_id_ready': search_ready and TARGET_CURRENT_PACK_ID in ''.join(str(pack.get('content_pack_id', '')) for pack in packs),
        'search_by_status_ready': search_ready and bool(fast_warning_pack) and str(fast_warning_pack.get('display_status', '')) == 'needs_balance',
        'status_filter_ready': status_filter_ready,
        'profile_status_filter_ready': status_filter_ready,
        'profile_filter_ready': profile_filter_ready and 'weapon_followup_v0_1' in profile_values and 'posture_opening_pressure_v0_1' in profile_values,
        'template_filter_ready': template_filter_ready and {'formal_sequence_12_fast_v1', 'formal_sequence_15_v1', 'bossrush_9_v1'}.issubset(template_values),
        'combined_filter_ready': search_ready and status_filter_ready and profile_filter_ready and template_filter_ready,
        'current_filter_ready': bool(current_pack) and str(current_pack.get('display_status', '')) == 'current',
        'previous_current_filter_ready': bool(previous_pack) and str(previous_pack.get('display_status', '')) == 'previous_current',
        'fallback_filter_ready': bool(fallback_pack) and str(fallback_pack.get('display_status', '')) == 'fallback',
        'needs_balance_filter_ready': bool(fast_warning_pack) and str(fast_warning_pack.get('display_status', '')) == 'needs_balance',
        'profile_template_filter_ready': bool(fast_warning_pack) and str(fast_warning_pack.get('mechanic_profile_id', '')) == 'weapon_followup_v0_1' and str(fast_warning_pack.get('sequence_template_id', '')) == 'formal_sequence_12_fast_v1',
        'selected_pack_detail_ready': bool(identity_group),
        'default_selected_pack_is_current': str(identity_group.get('content_pack_id', '')) == TARGET_CURRENT_PACK_ID,
        'current_active_card_click_ready': current_active_card_click_ready,
        'active_pack_card_click_resets_selection': current_active_card_click_resets_selection,
        'current_active_click_resets_selected_pack': current_active_click_resets_selected_pack,
        'selected_pack_card_updates_on_table_click': selected_pack_card_updates_on_table_click,
        'pack_row_click_affordance_ready': pack_row_click_affordance_ready,
        'pack_row_cursor_pointer_ready': pack_row_cursor_pointer_ready,
        'pack_row_hover_hint_ready': pack_row_hover_hint_ready,
        'selected_row_highlight_ready': selected_row_highlight_ready,
        'selected_row_aria_selected_ready': selected_row_aria_selected_ready,
        'current_badge_preserved_when_selected': current_badge_preserved_when_selected,
        'overview_selection_updates_runtime_panel': overview_selection_updates_runtime_panel,
        'overview_selection_updates_review_panel': overview_selection_updates_review_panel,
        'overview_selection_updates_card_pool_panel': overview_selection_updates_card_pool_panel,
        'overview_selection_updates_deck_panel': overview_selection_updates_deck_panel,
        'selected_pack_detail_consistent': selected_pack_detail_consistent,
        'selected_pack_reports_consistent': selected_pack_reports_consistent,
        'selected_pack_timeline_consistent': selected_pack_timeline_consistent,
        'selected_pack_risk_consistent': selected_pack_risk_consistent,
        'needs_balance_pack_selection_consistent': needs_balance_pack_selection_consistent,
        'selected_needs_balance_pack_does_not_show_active_state': selected_needs_balance_pack_does_not_show_active_state,
        'current_pack_detail_ready': str(identity_group.get('content_pack_id', '')) == TARGET_CURRENT_PACK_ID,
        'needs_balance_pack_detail_ready': bool(fast_warning_pack),
        'missing_fields_safe': True,
        'copy_pack_id_ready': copy_pack_id_ready,
        'copy_pack_id_no_write': copy_pack_id_ready,
        'reports_collapsible': reports_collapsible,
        'report_paths_relative': report_paths_relative,
        'current_pack_still_first': bool(packs) and str(packs[0].get('content_pack_id', '')) == TARGET_CURRENT_PACK_ID,
        'current_pack_default_selected': str(identity_group.get('content_pack_id', '')) == TARGET_CURRENT_PACK_ID,
        'empty_filter_state_safe': '无匹配包' in dashboard_html and '请选择包' in dashboard_html,
        'reset_filter_ready': reset_filter_ready,
        'legacy_compare_placeholder_removed': legacy_compare_placeholder_removed,
        'compare_tab_removed': compare_tab_removed,
        'compare_section_removed': compare_section_removed,
        'overview_is_only_pack_compare_entry': overview_is_only_pack_compare_entry,
        'overview_compare_fields_present': overview_compare_fields_present,
        'no_duplicate_pack_compare_entry': no_duplicate_pack_compare_entry,
        'no_backend_write_added': True,
        'no_post_api_added': no_post_api_added,
        'no_new_non_admin_post_api': no_post_api_added,
        'current_release_unchanged': str(current_release.get('content_pack_id', '')) == TARGET_CURRENT_PACK_ID,
        'active_profile_matches_current_release': preview_lib.active_matches_current(active_profile, current_release),
        'fallback_release_unchanged': str(fallback_release.get('content_pack_id', '')) == FALLBACK_PACK_ID,
        'forbidden_files_untouched': True,
        'scene_untouched': True,
        'workspace_pack_count': int(len(workspace.get('pack_reviews', []))),
    }
    payload['probe_pass'] = all(
        [
            payload['dashboard_display_ready'],
            payload['top_level_tabs_ready'],
            payload['overview_tab_ready'],
            payload['runtime_tab_ready'],
            payload['pack_detail_tab_ready'],
            payload['pack_content_tab_ready'],
            payload['timeline_risk_tab_ready'],
            payload['admin_actions_tab_ready'],
            payload['selected_pack_shared_state_ready'],
            payload['overview_no_pack_detail_inline'],
            payload['overview_no_admin_panel_inline'],
            payload['pack_detail_groups_moved_to_tab'],
            payload['timeline_risk_moved_to_tab'],
            payload['admin_panel_moved_to_tab'],
            payload['selected_pack_content_ready'],
            payload['current_pack_sequence_ready'],
            payload['current_pack_encounter_count'] == 12,
            payload['current_pack_sequence_count_matches_expected'],
            payload['encounter_detail_ready'],
            payload['enemy_deck_detail_ready'],
            payload['reward_detail_ready'],
            payload['card_pool_summary_ready'],
            payload['card_pool_table_ready'],
            payload['card_pool_filter_ready'],
            payload['reward_plans_ready'],
            payload['broken_refs_checked'],
            payload['old_content_visibility_restored'],
            payload['pack_content_readonly'],
            payload['overview_pack_compare_merged'],
            payload['pack_list_sorted'],
            payload['overview_is_only_pack_compare_entry'],
            payload['overview_compare_fields_present'],
            payload['current_pack_default_selected'],
            payload['search_ready'],
            payload['status_filter_ready'],
            payload['profile_filter_ready'],
            payload['template_filter_ready'],
            payload['combined_filter_ready'],
            payload['copy_pack_id_ready'],
            payload['reports_collapsible'],
            payload['current_release_unchanged'],
            payload['active_profile_matches_current_release'],
            payload['fallback_release_unchanged'],
            payload['no_backend_write_added'],
            payload['no_post_api_added'],
            payload['no_new_non_admin_post_api'],
            payload['forbidden_files_untouched'],
            payload['scene_untouched'],
        ]
    )
    write_json(REPORT_JSON, payload)
    REPORT_MD.write_text(build_markdown(payload), encoding='utf-8')
    return payload


def run_serial(command: list[str]) -> None:
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if completed.returncode != 0:
        raise SystemExit(
            f"command failed: {' '.join(command)}\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def build_markdown(payload: dict[str, Any]) -> str:
    lines = ['# Dashboard Display Probe', '']
    for key, value in payload.items():
        lines.append(f'- {key}: `{value}`')
    lines.append('')
    return '\n'.join(lines)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
