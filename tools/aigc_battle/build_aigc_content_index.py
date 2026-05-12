#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import switch_active_profile as switch_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import load_sequence_template as template_lib

MECHANICS_DIR = ROOT / 'data' / 'aigc_battle' / 'mechanics'
GENERATED_ROOT = ROOT / 'data' / 'aigc_battle' / 'generated'
RUNTIME_DIR = ROOT / 'data' / 'aigc_battle' / 'runtime'
DETAILS_DIR = GENERATED_ROOT / 'details'
INDEX_JSON = GENERATED_ROOT / 'aigc_content_index.json'
INDEX_MD = GENERATED_ROOT / 'aigc_content_index.md'
DASHBOARD_HTML = GENERATED_ROOT / 'aigc_content_dashboard.html'
PACK_REPORT_NAMES = [
    'validation_report.json',
    'runtime_manifest.json',
    'sequence_balance_summary.json',
    'telemetry_probe_report.json',
    'sequence_balance_snapshot.json',
    'runtime_primitive_probe_report.json',
    'rebuild_from_snapshot_probe_report.json',
    'full_sequence_reward_probe_report.json',
    'snapshot_summary.json',
]
EVALUATION_REPORTS_DIR = GENERATED_ROOT / 'evaluation' / 'reports'
EVALUATION_SNAPSHOT_DIR = ROOT / 'data' / 'aigc_battle' / 'evaluation' / 'snapshots'
REBUILD_RECOMMEND_DIR = ROOT / 'data' / 'aigc_battle' / 'evaluation' / 'rebuild_recommendations'
BALANCE_RELEASE_DIR = GENERATED_ROOT / 'balance_release'
TEMPLATE_PORTFOLIO_DIR = GENERATED_ROOT / 'template_portfolio'
MATRIX_DIR = GENERATED_ROOT / 'mechanic_template_matrix'


def main() -> int:
    write_index_artifacts()
    print('built aigc content index')
    return 0


def write_index_artifacts() -> dict[str, Any]:
    index_payload = build_index()
    GENERATED_ROOT.mkdir(parents=True, exist_ok=True)
    write_json(INDEX_JSON, index_payload)
    INDEX_MD.write_text(build_markdown(index_payload), encoding='utf-8')
    DASHBOARD_HTML.write_text(build_html(index_payload), encoding='utf-8')
    return index_payload


def build_index() -> dict[str, Any]:
    active_profile = read_json(RUNTIME_DIR / 'active_profile.json') if (RUNTIME_DIR / 'active_profile.json').exists() else {}
    active_profile_id = str(active_profile.get('active_mechanic_profile_id', ''))
    active_content_pack_id = str(active_profile.get('active_content_pack_id', ''))
    active_runtime_manifest_path = str(active_profile.get('runtime_manifest_path', ''))
    profiles: list[dict[str, Any]] = []
    content_pack_count = 0
    for profile_id in switch_lib.list_profile_ids():
        mechanic_dir = MECHANICS_DIR / profile_id
        root_generated_dir = GENERATED_ROOT / profile_id
        content_packs: list[dict[str, Any]] = []
        if (root_generated_dir / 'runtime_manifest.json').exists():
            content_packs.append(build_pack_entry(profile_id, None, active_profile_id, active_content_pack_id, active_runtime_manifest_path))
        packs_dir = root_generated_dir / 'packs'
        if packs_dir.exists():
            for pack_dir in sorted(path for path in packs_dir.iterdir() if path.is_dir()):
                if (pack_dir / 'runtime_manifest.json').exists():
                    content_packs.append(build_pack_entry(profile_id, pack_dir.name, active_profile_id, active_content_pack_id, active_runtime_manifest_path))
        content_pack_count += len(content_packs)
        profile_detail_json = DETAILS_DIR / f'profile_{profile_id}.json'
        profile_detail_md = DETAILS_DIR / f'profile_{profile_id}.md'
        profiles.append({
            'mechanic_profile_id': profile_id,
            'profile_dir': to_relative(mechanic_dir),
            'is_active_profile': profile_id == active_profile_id,
            'content_pack_count': len(content_packs),
            'profile_detail_json_path': to_relative(profile_detail_json) if profile_detail_json.exists() else '',
            'profile_detail_md_path': to_relative(profile_detail_md) if profile_detail_md.exists() else '',
            'content_packs': content_packs,
        })
    release_channels = release_lib.show_channels()
    current_release = release_channels.get('current_release', {})
    return {
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'active_profile_id': active_profile_id,
        'active_content_pack_id': active_content_pack_id,
        'active_runtime_manifest_path': active_runtime_manifest_path,
        'release_channels': release_channels,
        'active_profile_matches_current_release': bool(release_channels.get('active_runtime', {}).get('matches_current_release', False)),
        'active_profile_drift_from_current_release': bool(release_channels.get('active_runtime', {}).get('active_profile_drift_from_current_release', False)),
        'current_release_profile_id': str(current_release.get('mechanic_profile_id', '')),
        'current_release_content_pack_id': str(current_release.get('content_pack_id', '')),
        'profile_count': len(profiles),
        'content_pack_count': content_pack_count,
        'profiles': profiles,
    }


def build_pack_entry(profile_id: str, pack_id: str | None, active_profile_id: str, active_content_pack_id: str, active_runtime_manifest_path: str) -> dict[str, Any]:
    generated_dir = switch_lib.resolve_generated_dir(profile_id, pack_id)
    mechanic_path = MECHANICS_DIR / profile_id / 'mechanic_profile.json'
    mechanic_profile = try_read_json(mechanic_path) or {}
    validation_report = try_read_json(generated_dir / 'validation_report.json') or {}
    runtime_manifest = try_read_json(generated_dir / 'runtime_manifest.json') or {}
    balance_summary = try_read_json(generated_dir / 'sequence_balance_summary.json') or {}
    content_pack_summary = try_read_json(generated_dir / 'content_pack_summary.json') or {}
    telemetry_probe = try_read_json(generated_dir / 'telemetry_probe_report.json') or {}
    snapshot = try_read_json(generated_dir / 'sequence_balance_snapshot.json') or {}
    primitive_probe = try_read_json(generated_dir / 'runtime_primitive_probe_report.json') or {}
    reward_probe = try_read_json(generated_dir / 'full_sequence_reward_probe_report.json') or {}
    content_pack_id = str(runtime_manifest.get('content_pack_id') or validation_report.get('content_pack_id') or pack_id or '')
    sequence_template_id = str(
        content_pack_summary.get('sequence_template_id')
        or validation_report.get('sequence_template_id')
        or runtime_manifest.get('sequence_template_id')
        or template_lib.infer_sequence_template_id(content_pack_summary, runtime_manifest)
    )
    build_variant = template_lib.resolve_build_variant(
        content_pack_summary.get('build_variant') or validation_report.get('build_variant') or runtime_manifest.get('build_variant'),
        profile_id,
        content_pack_id,
    )
    total_encounter_count = int(
        content_pack_summary.get('total_encounter_count')
        or runtime_manifest.get('total_encounter_count')
        or validation_report.get('formal_encounter_total_count')
        or len(runtime_manifest.get('battle_slots', []))
        or 0
    )
    pack_identity = template_lib.build_pack_identity(sequence_template_id, profile_id, build_variant, content_pack_id)
    stage_counts = content_pack_summary.get('stage_counts') or runtime_manifest.get('stage_counts') or validation_report.get('stage_counts') or {}
    binding_valid = bool(validation_report.get('template_mechanic_pack_binding_valid', True))
    evaluation_report = try_read_json(EVALUATION_REPORTS_DIR / f'{profile_id}__{content_pack_id}__evaluation_report.json') or {}
    evaluation_snapshot = try_read_json(EVALUATION_SNAPSHOT_DIR / f'{profile_id}__{content_pack_id}__evaluation_snapshot.json') or {}
    rebuild_recommendations = try_read_json(REBUILD_RECOMMEND_DIR / f'{profile_id}__{content_pack_id}__rebuild_recommendations.json') or {}
    balance_build_report = try_read_json(BALANCE_RELEASE_DIR / 'balance_release_build_report.json') or {}
    balance_eval_report = try_read_json(BALANCE_RELEASE_DIR / 'balance_release_evaluation_report.json') or {}
    template_eval_report = try_read_json(TEMPLATE_PORTFOLIO_DIR / 'template_portfolio_evaluation_report.json') or {}
    template_strategy = try_read_json(TEMPLATE_PORTFOLIO_DIR / 'template_release_strategy.json') or {}
    template_metric = next((item for item in template_eval_report.get('template_metrics', []) if str(item.get('content_pack_id', '')) == content_pack_id), {})
    usage_recommendation = infer_template_usage_recommendation(sequence_template_id, template_strategy)
    matrix_build_report = try_read_json(MATRIX_DIR / 'matrix_build_report.json') or {}
    matrix_eval_report = try_read_json(MATRIX_DIR / 'matrix_evaluation_report.json') or {}
    matrix_strategy = try_read_json(MATRIX_DIR / 'matrix_release_strategy.json') or {}
    matrix_slot = next((item for item in matrix_build_report.get('matrix_slots', []) if str(item.get('content_pack_id', '')) == content_pack_id and str(item.get('mechanic_profile_id', '')) == profile_id), {})
    matrix_eval = next((item for item in matrix_eval_report.get('slots', []) if str(item.get('content_pack_id', '')) == content_pack_id and str(item.get('mechanic_profile_id', '')) == profile_id), {})
    balance_report_matches = str(balance_build_report.get('new_pack_id', '')) == content_pack_id or str(balance_eval_report.get('balanced_pack_id', '')) == content_pack_id
    release_channels = release_lib.show_channels()
    current_release = release_channels.get('current_release', {})
    candidate_release = release_channels.get('candidate_release', {})
    fallback_release = release_channels.get('fallback_release', {})
    runtime_manifest_path = generated_dir / 'runtime_manifest.json'
    is_active_pack = (
        profile_id == active_profile_id
        and content_pack_id == active_content_pack_id
        and to_relative(runtime_manifest_path) == active_runtime_manifest_path
    )
    switchability = switch_lib.get_switchability(profile_id, pack_id)
    missing_reports = [name for name in PACK_REPORT_NAMES if not (generated_dir / name).exists()]
    pack_detail_json = DETAILS_DIR / f'pack_{profile_id}__{content_pack_id}.json'
    pack_detail_md = DETAILS_DIR / f'pack_{profile_id}__{content_pack_id}.md'
    return {
        'mechanic_profile_id': profile_id,
        'content_pack_id': content_pack_id,
        'is_active_pack': is_active_pack,
        'pack_storage_mode': 'profile_pack_dir' if pack_id else 'profile_root',
        'generated_dir': to_relative(generated_dir),
        'runtime_manifest_path': to_relative(runtime_manifest_path) if runtime_manifest_path.exists() else '',
        'validation_report_path': to_relative(generated_dir / 'validation_report.json') if (generated_dir / 'validation_report.json').exists() else '',
        'sequence_template_id': sequence_template_id,
        'build_variant': build_variant,
        'total_encounter_count': total_encounter_count,
        'stage_counts': stage_counts,
        'pack_identity': pack_identity,
        'template_display_name': sequence_template_id,
        'template_usage_recommendation': usage_recommendation,
        'template_release_strategy': template_strategy if template_strategy else {},
        'matrix_slot': bool(matrix_slot),
        'matrix_mechanic_profile_id': profile_id if matrix_slot else '',
        'matrix_sequence_template_id': str(matrix_slot.get('sequence_template_id', '')),
        'matrix_build_variant': str(matrix_slot.get('build_variant', '')),
        'matrix_strategy_tag': infer_matrix_strategy_tag(content_pack_id, matrix_strategy),
        'template_mechanic_pack_binding_valid': binding_valid,
        'is_current_release': profile_id == str(current_release.get('mechanic_profile_id', '')) and content_pack_id == str(current_release.get('content_pack_id', '')),
        'is_candidate_release': profile_id == str(candidate_release.get('mechanic_profile_id', '')) and content_pack_id == str(candidate_release.get('content_pack_id', '')),
        'is_fallback_release': profile_id == str(fallback_release.get('mechanic_profile_id', '')) and content_pack_id == str(fallback_release.get('content_pack_id', '')),
        'sequence_balance_summary_path': to_relative(generated_dir / 'sequence_balance_summary.json') if (generated_dir / 'sequence_balance_summary.json').exists() else '',
        'telemetry_probe_report_path': to_relative(generated_dir / 'telemetry_probe_report.json') if (generated_dir / 'telemetry_probe_report.json').exists() else '',
        'sequence_balance_snapshot_path': to_relative(generated_dir / 'sequence_balance_snapshot.json') if (generated_dir / 'sequence_balance_snapshot.json').exists() else '',
        'runtime_primitive_probe_report_path': to_relative(generated_dir / 'runtime_primitive_probe_report.json') if (generated_dir / 'runtime_primitive_probe_report.json').exists() else '',
        'formal_encounter_total_count': int(validation_report.get('formal_encounter_total_count', runtime_manifest.get('balance_summary', {}).get('formal_encounter_total_count', 0) or 0)),
        'battle_slot_count': len(runtime_manifest.get('battle_slots', [])),
        'deck_count': len(runtime_manifest.get('enemy_decks', [])),
        'card_count': len(runtime_manifest.get('cards', [])),
        'reward_count': len(runtime_manifest.get('rewards', [])),
        'full_sequence_coverage_complete': bool(validation_report.get('full_sequence_coverage_complete', False)),
        'ready_for_runtime_export': bool(validation_report.get('ready_for_runtime_export', False)),
        'runtime_export_allowed': bool(validation_report.get('runtime_export_allowed', False)),
        'sequence_balance_pass': bool(validation_report.get('sequence_balance_pass', False)),
        'all_generated_slots_have_reward': bool(reward_probe.get('all_generated_slots_have_reward', len(runtime_manifest.get('rewards', [])) == len(runtime_manifest.get('battle_slots', [])) if runtime_manifest else False)),
        'fallback_loadout_count': int(reward_probe.get('fallback_loadout_count', telemetry_probe.get('fallback_telemetry_event_count', 0) or 0)),
        'runtime_primitives': [str(item) for item in runtime_manifest.get('runtime_primitives', mechanic_profile.get('runtime_primitives', []))],
        'opening_pressure_applied_count': int(primitive_probe.get('opening_pressure_applied_count', 0) or 0),
        'telemetry_event_count': int(snapshot.get('telemetry_event_count', telemetry_probe.get('telemetry_event_count', 0) or 0)),
        'snapshot_ready': bool(snapshot.get('snapshot_ready', False)),
        'rebuild_uses_snapshot': bool(balance_summary.get('rebuild_uses_snapshot', False) or validation_report.get('rebuild_uses_snapshot', False)),
        'last_modified': collect_last_modified(generated_dir),
        'missing_reports': missing_reports,
        'switchable': bool(switchability.get('switchable', False)),
        'switch_block_reasons': switchability.get('switch_block_reasons', []),
        'detail_missing': not (pack_detail_json.exists() and pack_detail_md.exists()),
        'pack_detail_json_path': to_relative(pack_detail_json) if pack_detail_json.exists() else '',
        'pack_detail_md_path': to_relative(pack_detail_md) if pack_detail_md.exists() else '',
        'deck_power_summary': {
            'early_avg_power': balance_summary.get('early_avg_power'),
            'mid_avg_power': balance_summary.get('mid_avg_power'),
            'late_avg_power': balance_summary.get('late_avg_power'),
            'boss_avg_power': balance_summary.get('boss_avg_power'),
        },
        'reward_tiers': collect_reward_tiers(runtime_manifest),
        'telemetry_summary': {
            'telemetry_event_count': int(snapshot.get('telemetry_event_count', telemetry_probe.get('telemetry_event_count', 0) or 0)),
            'encounters_with_telemetry_count': int(snapshot.get('encounters_with_telemetry_count', 0) or 0),
            'snapshot_ready': bool(snapshot.get('snapshot_ready', False)),
        },
        'evaluation_report_path': to_relative(EVALUATION_REPORTS_DIR / f'{profile_id}__{content_pack_id}__evaluation_report.json') if evaluation_report else '',
        'evaluation_snapshot_path': to_relative(EVALUATION_SNAPSHOT_DIR / f'{profile_id}__{content_pack_id}__evaluation_snapshot.json') if evaluation_snapshot else '',
        'rebuild_recommendations_path': to_relative(REBUILD_RECOMMEND_DIR / f'{profile_id}__{content_pack_id}__rebuild_recommendations.json') if rebuild_recommendations else '',
        'evaluation_event_count': int(evaluation_report.get('evaluation_event_count', evaluation_snapshot.get('evaluation_event_count', 0) or 0)),
        'evaluated': bool(evaluation_report or evaluation_snapshot),
        'win_rate': float(evaluation_snapshot.get('pack_metrics', {}).get('win_rate', evaluation_report.get('pack_metrics', {}).get('win_rate', 0)) or 0),
        'avg_turn_count': float(evaluation_snapshot.get('pack_metrics', {}).get('avg_turn_count', evaluation_report.get('pack_metrics', {}).get('avg_turn_count', 0)) or 0),
        'avg_player_hp_end': float(evaluation_snapshot.get('pack_metrics', {}).get('avg_player_hp_end', evaluation_report.get('pack_metrics', {}).get('avg_player_hp_end', 0)) or 0),
        'mechanic_trigger_rate': float(evaluation_snapshot.get('mechanic_metrics', {}).get('runtime_primitive_trigger_rate', evaluation_report.get('pack_metrics', {}).get('runtime_primitive_trigger_rate', 0)) or 0),
        'actionability_score': int(evaluation_snapshot.get('actionability_score', 0) or 0),
        'needs_rebuild': bool(int(evaluation_snapshot.get('rebuild_recommendation_count', rebuild_recommendations.get('recommendation_count', 0) or 0)) > 0),
        'template_portfolio_metrics': template_metric,
        'matrix_evaluation_summary': matrix_eval,
        'needs_balance_before_release': bool(matrix_eval.get('needs_balance_before_release', False)),
        'ready_for_candidate_review': bool(matrix_eval.get('ready_for_candidate_review', False)),
        'balance_release': bool(content_pack_summary.get('balance_release', False)),
        'source_pack_id': str(content_pack_summary.get('source_pack_id', '')),
        'playable_balance_gate_pass': bool(balance_eval_report.get('playable_balance_gate_pass', False)) if balance_report_matches else False,
        'current_release_is_balanced': bool(content_pack_summary.get('balance_release', False) and profile_id == str(current_release.get('mechanic_profile_id', '')) and content_pack_id == str(current_release.get('content_pack_id', ''))),
    }


def infer_template_usage_recommendation(sequence_template_id: str, strategy: dict[str, Any]) -> str:
    mapping = {
        'recommended_standard_template': 'standard_run',
        'recommended_fast_template': 'fast_run',
        'recommended_bossrush_template': 'boss_rush',
        'recommended_elite_template': 'elite_pressure',
    }
    for key, label in mapping.items():
        if str(strategy.get(key, '')).strip() == sequence_template_id:
            return label
    return ''


def infer_matrix_strategy_tag(content_pack_id: str, strategy: dict[str, Any]) -> str:
    mapping = {
        'recommended_standard_candidate': 'standard_candidate',
        'recommended_fast_candidate': 'fast_candidate',
        'recommended_bossrush_candidate': 'bossrush_candidate',
        'recommended_mechanic_showcase_candidate': 'mechanic_showcase',
    }
    for key, label in mapping.items():
        value = strategy.get(key, {})
        if isinstance(value, dict) and str(value.get('content_pack_id', '')) == content_pack_id:
            return label
    return ''


def build_markdown(index_payload: dict[str, Any]) -> str:
    lines = [
        '# AIGC Battle 外部内容总览',
        '',
        f"- 当前 active profile: `{index_payload['active_profile_id']}`",
        f"- 当前 active content pack: `{index_payload['active_content_pack_id']}`",
        f"- 当前 manifest: `{index_payload['active_runtime_manifest_path']}`",
        f"- Current Release: `{index_payload['current_release_profile_id']}` / `{index_payload['current_release_content_pack_id']}`",
        f"- active_profile_drift_from_current_release: `{index_payload['active_profile_drift_from_current_release']}`",
        f"- profile 数量: `{index_payload['profile_count']}`",
        f"- content pack 数量: `{index_payload['content_pack_count']}`",
        '',
        '| Active | Profile | Pack | Mode | Encounters | Cards | Decks | Rewards | Export | Balance | Runtime Export | Primitive | Detail |',
        '| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- |',
    ]
    for profile in index_payload['profiles']:
        for pack in profile['content_packs']:
            lines.append(
                "| {active} | `{profile}` | `{pack_id}` | `{mode}` | {enc} | {cards} | {decks} | {rewards} | {export} | {balance} | {runtime_export} | `{primitives}` | {detail} |".format(
                    active='YES' if pack['is_active_pack'] else '',
                    profile=profile['mechanic_profile_id'],
                    pack_id=pack['content_pack_id'],
                    mode=pack['pack_storage_mode'],
                    enc=pack['formal_encounter_total_count'],
                    cards=pack['card_count'],
                    decks=pack['deck_count'],
                    rewards=pack['reward_count'],
                    export='PASS' if pack['ready_for_runtime_export'] else 'FAIL',
                    balance='PASS' if pack['sequence_balance_pass'] else 'FAIL',
                    runtime_export='PASS' if pack['runtime_export_allowed'] else 'FAIL',
                    primitives=','.join(pack['runtime_primitives']) or '-',
                    detail='ready' if not pack['detail_missing'] else 'missing',
                )
            )
    lines.extend([
        '',
        '## 控制台命令',
        '',
        '- 列出可切换 pack：`python3 tools/aigc_battle/aigc_external_profile_switch.py --list`',
        '- 干跑 root pack：`python3 tools/aigc_battle/aigc_external_profile_switch.py --dry-run --profile <profile_id>`',
        '- 干跑指定 pack：`python3 tools/aigc_battle/aigc_external_profile_switch.py --dry-run --profile <profile_id> --pack <content_pack_id>`',
        '- 安全切换 root pack：`python3 tools/aigc_battle/aigc_external_profile_switch.py --profile <profile_id>`',
        '- 安全切换指定 pack：`python3 tools/aigc_battle/aigc_external_profile_switch.py --profile <profile_id> --pack <content_pack_id>`',
        '- 浏览器点击切换或查看明细前先启动本地 server：`python3 tools/aigc_battle/aigc_dashboard_server.py`',
    ])
    return '\n'.join(lines) + '\n'


def build_html(index_payload: dict[str, Any]) -> str:
    data_json = json.dumps(index_payload, ensure_ascii=False)
    return f'''<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AIGC Battle External Console</title>
<style>
:root {{ --bg:#f5f1e8; --card:#fffaf1; --ink:#1f1d1a; --muted:#6a6258; --ok:#2f7d32; --bad:#9a2f2f; --line:#d9cfbf; --accent:#9b6b2e; --accent2:#1d5b73; }}
body {{ margin:0; font-family: Georgia, 'Songti SC', serif; background:linear-gradient(180deg,#efe5d1,#f8f4ec); color:var(--ink); }}
main {{ max-width:1380px; margin:0 auto; padding:28px 20px 80px; }}
header {{ margin-bottom:24px; padding:24px; background:rgba(255,250,241,.9); border:1px solid var(--line); border-radius:18px; box-shadow:0 12px 40px rgba(73,53,30,.08); }}
.layout {{ display:grid; grid-template-columns: minmax(0, 2fr) minmax(320px, 1fr); gap:20px; align-items:start; }}
.notice {{ margin-top:12px; padding:10px 12px; border-radius:12px; background:#f1e8d8; color:#704d1f; }}
.profile {{ margin-bottom:18px; padding:18px; background:rgba(255,250,241,.88); border:1px solid var(--line); border-radius:18px; box-shadow:0 10px 30px rgba(73,53,30,.06); }}
.pack-grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(300px,1fr)); gap:16px; margin-top:14px; }}
.pack-card {{ background:var(--card); border:1px solid var(--line); border-radius:16px; padding:16px; }}
.pack-card.active {{ outline:3px solid rgba(155,107,46,.25); }}
.badge {{ display:inline-block; padding:4px 10px; border-radius:999px; background:#efe2c9; color:#704d1f; font-size:12px; margin-right:8px; margin-bottom:6px; }}
.badge.ok {{ background:#dff0e0; color:var(--ok); }}
.badge.bad {{ background:#f5dddd; color:var(--bad); }}
.badge.info {{ background:#dceaf0; color:var(--accent2); }}
button {{ border:none; border-radius:10px; padding:10px 14px; margin-right:8px; margin-top:8px; cursor:pointer; background:#1d5b73; color:white; font:inherit; }}
button.secondary {{ background:#9b6b2e; }}
button[disabled] {{ opacity:.45; cursor:not-allowed; }}
pre {{ white-space:pre-wrap; word-break:break-word; background:#f7f0e3; border-radius:12px; padding:12px; color:var(--muted); }}
.small {{ color:var(--muted); font-size:13px; }}
.sidebar {{ position:sticky; top:20px; background:rgba(255,250,241,.92); border:1px solid var(--line); border-radius:18px; padding:18px; box-shadow:0 10px 30px rgba(73,53,30,.06); }}
.sidebar h2 {{ margin-top:0; }}
</style>
</head>
<body>
<main>
<header>
  <h1>AIGC Battle External Console</h1>
  <p>当前 active profile：<code id="active-profile"></code></p>
  <p>当前 active content pack：<code id="active-pack"></code></p>
  <p>当前 runtime manifest：<code id="active-manifest"></code></p>
  <div class="notice" id="mode-notice"></div>
  <pre id="status-box">等待操作。</pre>
</header>
<div class="layout">
  <section id="profiles"></section>
  <aside class="sidebar">
    <h2 id="detail-title">明细面板</h2>
    <div id="detail-summary" class="small">点击“查看机制明细”或“查看内容包明细”加载数据。</div>
    <pre id="detail-box">{{}}</pre>
  </aside>
</div>
</main>
<script>
const embeddedIndex = {data_json};
const state = {{ index: embeddedIndex, apiEnabled: location.protocol !== 'file:' }};
const profilesEl = document.getElementById('profiles');
const statusBox = document.getElementById('status-box');
const modeNotice = document.getElementById('mode-notice');
const detailTitle = document.getElementById('detail-title');
const detailSummary = document.getElementById('detail-summary');
const detailBox = document.getElementById('detail-box');

function setStatus(message) {{ statusBox.textContent = message; }}
function setDetail(title, summary, payload) {{ detailTitle.textContent = title; detailSummary.textContent = summary; detailBox.textContent = JSON.stringify(payload, null, 2); }}

async function loadIndex() {{
  if (!state.apiEnabled) return state.index;
  const response = await fetch('/api/index');
  const payload = await response.json();
  state.index = payload;
  return payload;
}}

async function fetchDetail(kind, profileId, contentPackId) {{
  if (!state.apiEnabled) throw new Error('静态模式不支持加载 detail API');
  const url = kind === 'profile'
    ? `/api/profile-detail?profile_id=${{encodeURIComponent(profileId)}}`
    : `/api/pack-detail?profile_id=${{encodeURIComponent(profileId)}}&content_pack_id=${{encodeURIComponent(contentPackId || '')}}`;
  const response = await fetch(url);
  const payload = await response.json();
  if (!response.ok || payload.ok === false) throw new Error(payload.error || 'detail request failed');
  return payload;
}}

async function callSwitchApi(path, profileId, packId) {{
  const response = await fetch(path, {{
    method: 'POST',
    headers: {{ 'Content-Type': 'application/json' }},
    body: JSON.stringify({{ profile_id: profileId, content_pack_id: packId || '' }})
  }});
  const payload = await response.json();
  if (!response.ok || payload.ok === false || payload.can_switch === false) {{
    throw new Error(payload.error || (payload.reasons || []).join('; ') || '请求失败');
  }}
  return payload;
}}

function render() {{
  const index = state.index;
  document.getElementById('active-profile').textContent = index.active_profile_id || '-';
  document.getElementById('active-pack').textContent = index.active_content_pack_id || '-';
  document.getElementById('active-manifest').textContent = index.active_runtime_manifest_path || '-';
  modeNotice.textContent = state.apiEnabled
    ? '当前为 localhost server 模式，可点击查看明细、Dry Run 或 启用此内容包。'
    : '当前为 file:// 静态模式，只读查看摘要。若要查看完整 detail 和点击切换，请先运行 python3 tools/aigc_battle/aigc_dashboard_server.py';
  profilesEl.innerHTML = '';
  for (const profile of index.profiles) {{
    const section = document.createElement('section');
    section.className = 'profile';
    section.innerHTML = `<h2>${{profile.mechanic_profile_id}}</h2><div class="small">content packs: ${{profile.content_pack_count}}</div>`;
    const profileDetailButton = document.createElement('button');
    profileDetailButton.textContent = '查看机制明细';
    profileDetailButton.disabled = !state.apiEnabled;
    profileDetailButton.onclick = async () => {{
      try {{
        const payload = await fetchDetail('profile', profile.mechanic_profile_id, '');
        setDetail(`机制包明细: ${{profile.mechanic_profile_id}}`, 'profile / recipe 规则摘要', payload);
      }} catch (error) {{ setStatus(`读取机制明细失败: ${{error.message}}`); }}
    }};
    section.appendChild(profileDetailButton);
    const grid = document.createElement('div');
    grid.className = 'pack-grid';
    for (const pack of profile.content_packs) {{
      const card = document.createElement('article');
      card.className = 'pack-card' + (pack.is_active_pack ? ' active' : '');
      const switchable = !!pack.switchable;
      const reasons = (pack.switch_block_reasons || []).join('; ');
      card.innerHTML = `
        <div>
          ${{pack.is_active_pack ? '<span class="badge">ACTIVE</span>' : ''}}
          <span class="badge info">${{pack.pack_storage_mode}}</span>
          <span class="badge ${{pack.ready_for_runtime_export ? 'ok' : 'bad'}}">EXPORT ${{pack.ready_for_runtime_export ? 'PASS' : 'FAIL'}}</span>
          <span class="badge ${{pack.sequence_balance_pass ? 'ok' : 'bad'}}">BALANCE ${{pack.sequence_balance_pass ? 'PASS' : 'FAIL'}}</span>
        </div>
        <h3>${{pack.content_pack_id || '(missing pack id)'}}</h3>
        <div class="small">manifest: <code>${{pack.runtime_manifest_path}}</code></div>
        <p>Encounters: ${{pack.formal_encounter_total_count}} | Battles: ${{pack.battle_slot_count}}</p>
        <p>Cards: ${{pack.card_count}} | Decks: ${{pack.deck_count}} | Rewards: ${{pack.reward_count}}</p>
        <p>Runtime primitives: <code>${{(pack.runtime_primitives || []).join(', ') || '-'}}</code></p>
        <p>Telemetry: ${{pack.telemetry_event_count}} | Snapshot: ${{pack.snapshot_ready ? 'ready' : 'missing'}}</p>
        <p class="small">switchable: ${{switchable ? 'yes' : 'no'}} | detail: ${{pack.detail_missing ? 'missing' : 'ready'}}</p>
        <pre>${{reasons || '无阻塞原因'}}</pre>
      `;
      const detailButton = document.createElement('button');
      detailButton.textContent = '查看内容包明细';
      detailButton.disabled = !state.apiEnabled;
      detailButton.onclick = async () => {{
        try {{
          const payload = await fetchDetail('pack', pack.mechanic_profile_id, pack.pack_storage_mode === 'profile_pack_dir' ? pack.content_pack_id : '');
          setDetail(`内容包明细: ${{pack.content_pack_id}}`, 'pack 总览 / 卡池 / formal sequence 明细', payload);
        }} catch (error) {{ setStatus(`读取内容包明细失败: ${{error.message}}`); }}
      }};
      const dryButton = document.createElement('button');
      dryButton.textContent = 'Dry Run';
      const switchButton = document.createElement('button');
      switchButton.textContent = '启用此内容包';
      switchButton.className = 'secondary';
      const commandHint = document.createElement('div');
      commandHint.className = 'small';
      const packArg = pack.pack_storage_mode === 'profile_pack_dir' ? ` --pack ${{pack.content_pack_id}}` : '';
      commandHint.innerHTML = `命令行：<code>python3 tools/aigc_battle/aigc_external_profile_switch.py --profile ${{pack.mechanic_profile_id}}${{packArg}}</code>`;
      if (!state.apiEnabled) {{
        dryButton.disabled = true;
        switchButton.disabled = true;
      }} else {{
        dryButton.disabled = !switchable;
        switchButton.disabled = !switchable || pack.is_active_pack;
        dryButton.onclick = async () => {{
          try {{
            const payload = await callSwitchApi('/api/dry-run-switch', pack.mechanic_profile_id, pack.pack_storage_mode === 'profile_pack_dir' ? pack.content_pack_id : '');
            setStatus(JSON.stringify(payload, null, 2));
          }} catch (error) {{ setStatus(`Dry Run 失败: ${{error.message}}`); }}
        }};
        switchButton.onclick = async () => {{
          try {{
            const payload = await callSwitchApi('/api/switch-pack', pack.mechanic_profile_id, pack.pack_storage_mode === 'profile_pack_dir' ? pack.content_pack_id : '');
            await loadIndex();
            render();
            setStatus(JSON.stringify(payload, null, 2));
          }} catch (error) {{ setStatus(`切换失败: ${{error.message}}`); }}
        }};
      }}
      card.appendChild(detailButton);
      card.appendChild(dryButton);
      card.appendChild(switchButton);
      card.appendChild(commandHint);
      grid.appendChild(card);
    }}
    section.appendChild(grid);
    profilesEl.appendChild(section);
  }}
}}

(async function init() {{
  if (state.apiEnabled) {{
    try {{ await loadIndex(); }} catch (error) {{ setStatus(`读取 /api/index 失败: ${{error.message}}`); }}
  }}
  render();
}})();
</script>
</body>
</html>'''


def collect_reward_tiers(runtime_manifest: dict[str, Any]) -> list[str]:
    return sorted({str(item.get('reward_tier', '')).strip() for item in runtime_manifest.get('rewards', []) if str(item.get('reward_tier', '')).strip()})


def collect_last_modified(path: Path) -> str:
    latest = None
    for child in path.rglob('*') if path.exists() else []:
        if child.is_file():
            latest = max(latest, child.stat().st_mtime) if latest is not None else child.stat().st_mtime
    if latest is None:
        return ''
    return datetime.fromtimestamp(latest, tz=timezone.utc).isoformat()


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def try_read_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return read_json(path)


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    raise SystemExit(main())
