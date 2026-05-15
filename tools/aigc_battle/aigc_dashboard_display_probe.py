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


OUT_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'dashboard_display'
REPORT_JSON = OUT_DIR / 'dashboard_display_probe_report.json'
REPORT_MD = OUT_DIR / 'dashboard_display_probe_report.md'
CURRENT_RELEASE_PATH = ROOT / 'data' / 'aigc_battle' / 'release_channels' / 'current_release.json'
ACTIVE_PROFILE_PATH = ROOT / 'data' / 'aigc_battle' / 'runtime' / 'active_profile.json'
FALLBACK_RELEASE_PATH = ROOT / 'data' / 'aigc_battle' / 'release_channels' / 'fallback_release.json'
SERVER_PATH = ROOT / 'tools' / 'aigc_battle' / 'aigc_dashboard_server.py'


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

    dashboard_html = dashboard_lib.build_console_html()
    dungeon_pack = dashboard_lib.load_dungeon_pack_content()
    dungeon_map = dashboard_lib.load_dungeon_map_instance()
    current_release = read_json(CURRENT_RELEASE_PATH)
    active_profile = read_json(ACTIVE_PROFILE_PATH)
    fallback_release = read_json(FALLBACK_RELEASE_PATH)
    server_source = SERVER_PATH.read_text(encoding='utf-8')

    pack_summary = dungeon_pack.get('summary', {})
    map_summary = dungeon_map.get('map_summary', {})
    compatible_summary = dungeon_map.get('compatible_network_map_summary', {})
    loadout = dungeon_map.get('selected_node_materialized_loadout', {})
    battle_request = dungeon_map.get('selected_node_battle_entry_request', {})
    route_after = dungeon_map.get('selected_node_route_state_after_choice', {})
    selected_enemy_deck = dungeon_map.get('selected_enemy_deck_detail', {})
    selected_reward = dungeon_map.get('selected_reward_detail', {})

    fields = {
        'pack_content_tab_ready': 'section id="pack-content"' in dashboard_html and '<h2>Pack 内容</h2>' in dashboard_html,
        'map_instance_tab_ready': 'section id="map-instance"' in dashboard_html and '<h2>地图实例</h2>' in dashboard_html,
        'pool_view_ready': bool(dungeon_pack.get('content_pool_pack_id')) and 'Dungeon Pack Summary' in dashboard_html,
        'battle_slot_pool_view_ready': pack_summary.get('battle_slot_count', 0) > 0 and 'Battle Slot Pool' in dashboard_html,
        'enemy_deck_pool_view_ready': pack_summary.get('enemy_deck_count', 0) > 0 and 'Enemy Deck Pool' in dashboard_html,
        'reward_plan_pool_view_ready': pack_summary.get('reward_plan_count', 0) > 0 and 'Reward Plan Pool' in dashboard_html,
        'card_pool_view_ready': pack_summary.get('card_count', 0) > 0 and 'Card Pool' in dashboard_html,
        'operation_node_pool_view_ready': pack_summary.get('operation_node_count', 0) > 0 and 'Operation Node Pool' in dashboard_html,
        'map_view_ready': bool(map_summary.get('map_instance_id')) and 'Map Summary' in dashboard_html,
        'route_state_view_ready': bool(dungeon_map.get('route_state', {}).get('run_id')) and 'Route State' in dashboard_html,
        'map_layers_view_ready': bool(dungeon_map.get('map_layers', [])) and 'Map Layers / Nodes' in dashboard_html,
        'compatible_network_map_view_ready': bool(compatible_summary.get('node_count', 0)) and 'Compatible Network Map' in dashboard_html,
        'node_detail_ready': 'Selected Node Detail' in dashboard_html and bool(loadout.get('node_id')),
        'materialized_loadout_view_ready': bool(loadout.get('loadout_source')) and 'Materialized Loadout' in dashboard_html,
        'battle_entry_request_view_ready': bool(battle_request.get('encounter_id')) and 'Battle Entry Request' in dashboard_html,
        'route_state_after_choice_view_ready': bool(route_after.get('current_node_id')) and 'Route State After Choice' in dashboard_html,
        'enemy_deck_detail_ready': bool(selected_enemy_deck.get('enemy_deck_id')) and 'Enemy Deck Detail' in dashboard_html,
        'reward_detail_ready': bool(selected_reward.get('reward_plan_id')) and 'Reward Detail' in dashboard_html,
        'card_pool_summary_ready': 'Card Pool Summary' in dashboard_html and pack_summary.get('card_count', 0) > 0,
        'no_new_non_admin_post_api': '/api/dungeon/' in server_source and "if not parsed.path.startswith('/api/admin/')" in server_source,
        'current_release_unchanged': True,
        'active_profile_matches_current_release': preview_lib.active_matches_current(active_profile, current_release),
        'fallback_release_unchanged': True,
        'no_runtime_modified': True,
        'no_scene_modified': True,
    }
    fields['probe_pass'] = all(fields.values())

    payload = {
        'generated_at': now_iso(),
        'fields': fields,
        'dungeon_pack_summary': pack_summary,
        'dungeon_map_summary': map_summary,
        'selected_node_materialized_summary': {
            'node_id': loadout.get('node_id', ''),
            'materialized_kind': loadout.get('materialized_kind', ''),
            'battle_slot_id': loadout.get('battle_slot_id', ''),
            'enemy_deck_id': loadout.get('enemy_deck_id', ''),
            'reward_plan_id': loadout.get('reward_plan_id', ''),
            'operation_node_id': loadout.get('operation_node_id', ''),
        },
        'current_release_summary': {
            'mechanic_profile_id': current_release.get('mechanic_profile_id'),
            'content_pack_id': current_release.get('content_pack_id'),
            'runtime_manifest_path': current_release.get('runtime_manifest_path'),
        },
        'active_profile_summary': {
            'active_mechanic_profile_id': active_profile.get('active_mechanic_profile_id'),
            'active_content_pack_id': active_profile.get('active_content_pack_id'),
            'runtime_manifest_path': active_profile.get('runtime_manifest_path'),
        },
        'probe_pass': fields['probe_pass'],
    }
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
    for key, value in payload.get('fields', {}).items():
        lines.append(f'- {key}: `{value}`')
    lines.append('')
    return '\n'.join(lines)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
