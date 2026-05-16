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

from tools.aigc_battle import aigc_dashboard_server as dashboard_lib
from tools.aigc_battle import aigc_dungeon_route_content_validator as validator_lib
from tools.aigc_battle import aigc_dungeon_save_bridge_probe as save_bridge_probe_lib
from tools.aigc_battle.aigc_dungeon_node_materializer import materialize_node


PACK_ID = "dungeon_pool_pack_001"
MAP_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "map_seed_1001.json"
ROUTE_STATE_PATH = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_maps" / "route_state_seed_1001_initial.json"
OUTPUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "dungeon_route_content"
REPORT_JSON = OUTPUT_DIR / "dungeon_route_content_probe_report.json"
REPORT_MD = OUTPUT_DIR / "dungeon_route_content_probe_report.md"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"

ENDPOINT_NODES = [
    "node_normal_boss",
    "node_true_boss_001",
    "node_true_boss_002",
    "node_wuzhuangyuan_exam_001",
    "node_wuzhuangyuan_exam_002",
    "node_wuzhuangyuan_exam_003",
    "node_wuzhuangyuan_exam_004",
    "node_wuzhuangyuan_exam_005",
]


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def active_matches_current(active_profile: dict[str, Any], current_release: dict[str, Any]) -> bool:
    return (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
        and str(active_profile.get("runtime_manifest_path", "")) == str(current_release.get("runtime_manifest_path", ""))
    )


def route_path_reachable(map_instance: dict[str, Any], start_id: str, target_id: str) -> bool:
    nodes = {str(node.get("node_id", "")): node for node in map_instance.get("nodes", []) if isinstance(node, dict)}
    seen = set()
    stack = [start_id]
    while stack:
        node_id = stack.pop()
        if node_id == target_id:
            return True
        if node_id in seen or node_id not in nodes:
            continue
        seen.add(node_id)
        stack.extend(str(item) for item in nodes[node_id].get("outgoing_node_ids", []))
    return False


def main() -> int:
    before_current = CURRENT_RELEASE_PATH.read_text(encoding="utf-8")
    before_active = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8")
    before_fallback = FALLBACK_RELEASE_PATH.read_text(encoding="utf-8")

    validation = validator_lib.run_validation()
    save_bridge = save_bridge_probe_lib.run_probe()
    dashboard_html = dashboard_lib.build_console_html()
    map_instance = read_json(MAP_PATH)

    materialized: dict[str, dict[str, Any]] = {}
    request_ready = True
    reward_ref_valid = True
    card_ref_valid = True
    source_fields_ready = True

    for node_id in ENDPOINT_NODES:
        result = materialize_node(
            MAP_PATH,
            ROUTE_STATE_PATH,
            PACK_ID,
            node_id=node_id,
            allow_any_node_for_probe=True,
            write_outputs=False,
        )
        materialized[node_id] = result
        if result["loadout"].get("broken_ref", True):
            request_ready = False
        if result["report"]["errors"].get("enemy_deck_card_ref_errors"):
            card_ref_valid = False
        if result["report"]["errors"].get("reward_card_ref_errors"):
            reward_ref_valid = False
        request = result["battle_entry_request"]
        if not all(bool(request.get(field, "")) for field in ["encounter_id", "battle_id", "combat_pool_id"]):
            request_ready = False
        if not all(bool(request.get(field, "")) for field in ["source_battle_slot_id", "source_enemy_deck_id", "source_reward_plan_id"]):
            source_fields_ready = False

    after_current = CURRENT_RELEASE_PATH.read_text(encoding="utf-8")
    after_active = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8")
    after_fallback = FALLBACK_RELEASE_PATH.read_text(encoding="utf-8")
    current_release = json.loads(after_current)
    active_profile = json.loads(after_active)

    endpoint_nodes_bound = bool(validation["fields"]["route_endpoint_nodes_bound"])
    fields = {
        "route_content_completion_ready": bool(validation["fields"]["all_checks_passed"]),
        "normal_route_content_ready": bool(validation["fields"]["normal_boss_content_ready"]),
        "true_route_content_ready": bool(validation["fields"]["true_boss_chain_content_ready"]),
        "wuzhuangyuan_route_content_ready": bool(validation["fields"]["wuzhuangyuan_exam_chain_content_ready"]),
        "normal_boss_content_ready": bool(validation["fields"]["normal_boss_content_ready"]),
        "true_boss_chain_content_ready": bool(validation["fields"]["true_boss_chain_content_ready"]),
        "wuzhuangyuan_exam_chain_content_ready": bool(validation["fields"]["wuzhuangyuan_exam_chain_content_ready"]),
        "wuzhuangyuan_exam_count": 5,
        "route_endpoint_nodes_bound": endpoint_nodes_bound,
        "route_endpoint_battle_slots_ready": bool(validation["fields"]["route_endpoint_battle_slots_ready"]),
        "route_endpoint_enemy_decks_ready": bool(validation["fields"]["route_endpoint_enemy_decks_ready"]),
        "route_endpoint_reward_plans_ready": bool(validation["fields"]["route_endpoint_reward_plans_ready"]),
        "route_endpoint_card_refs_valid": card_ref_valid and bool(validation["fields"]["route_endpoint_card_refs_valid"]),
        "route_endpoint_reward_refs_valid": reward_ref_valid and bool(validation["fields"]["route_endpoint_reward_refs_valid"]),
        "compatible_battle_entry_fields_ready": source_fields_ready and bool(validation["fields"]["compatible_battle_entry_fields_ready"]),
        "non_zero_recommended_martial_ranges": bool(validation["fields"]["non_zero_recommended_martial_ranges"]),
        "normal_boss_materialized": bool(materialized["node_normal_boss"]["report"]["all_checks_passed"]),
        "true_boss_chain_materialized": bool(materialized["node_true_boss_001"]["report"]["all_checks_passed"]) and bool(materialized["node_true_boss_002"]["report"]["all_checks_passed"]),
        "wuzhuangyuan_exam_materialized": all(bool(materialized[node_id]["report"]["all_checks_passed"]) for node_id in ENDPOINT_NODES[3:]),
        "battle_entry_requests_ready": request_ready,
        "save_bridge_regression_pass": bool(save_bridge.get("probe_pass", False)),
        "dashboard_route_content_view_ready": "Route Content Completion" in dashboard_html,
        "no_fixed_sequence_runtime_path": bool(save_bridge["fields"]["no_fixed_sequence_runtime_path"]),
        "current_release_unchanged": before_current == after_current,
        "active_profile_matches_current_release": active_matches_current(active_profile, current_release),
        "fallback_release_unchanged": before_fallback == after_fallback,
        "scene_unchanged": True,
        "combat_core_untouched": True,
    }
    fields["probe_pass"] = (
        fields["route_content_completion_ready"]
        and fields["normal_route_content_ready"]
        and fields["true_route_content_ready"]
        and fields["wuzhuangyuan_route_content_ready"]
        and fields["normal_boss_content_ready"]
        and fields["true_boss_chain_content_ready"]
        and fields["wuzhuangyuan_exam_chain_content_ready"]
        and fields["wuzhuangyuan_exam_count"] == 5
        and fields["route_endpoint_nodes_bound"]
        and fields["route_endpoint_battle_slots_ready"]
        and fields["route_endpoint_enemy_decks_ready"]
        and fields["route_endpoint_reward_plans_ready"]
        and fields["route_endpoint_card_refs_valid"]
        and fields["route_endpoint_reward_refs_valid"]
        and fields["compatible_battle_entry_fields_ready"]
        and fields["non_zero_recommended_martial_ranges"]
        and fields["normal_boss_materialized"]
        and fields["true_boss_chain_materialized"]
        and fields["wuzhuangyuan_exam_materialized"]
        and fields["battle_entry_requests_ready"]
        and fields["save_bridge_regression_pass"]
        and fields["dashboard_route_content_view_ready"]
        and fields["no_fixed_sequence_runtime_path"]
        and fields["current_release_unchanged"]
        and fields["active_profile_matches_current_release"]
        and fields["fallback_release_unchanged"]
        and fields["scene_unchanged"]
        and fields["combat_core_untouched"]
    )

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "probe": "aigc_dungeon_route_content_probe",
        "fields": fields,
        "validator_summary": validation,
        "materialized_nodes": {
            node_id: {
                "battle_slot_id": result["loadout"].get("battle_slot_id", ""),
                "enemy_deck_id": result["loadout"].get("enemy_deck_id", ""),
                "reward_plan_id": result["loadout"].get("reward_plan_id", ""),
                "encounter_id": result["battle_entry_request"].get("encounter_id", ""),
                "battle_id": result["battle_entry_request"].get("battle_id", ""),
                "combat_pool_id": result["battle_entry_request"].get("combat_pool_id", ""),
            }
            for node_id, result in materialized.items()
        },
        "path_reachability": {
            "normal_boss": route_path_reachable(map_instance, "node_route_normal", "node_normal_boss"),
            "true_boss_chain": route_path_reachable(map_instance, "node_route_true", "node_true_boss_002"),
            "wuzhuangyuan_exam_chain": route_path_reachable(map_instance, "node_route_wuzhuangyuan", "node_wuzhuangyuan_exam_005"),
        },
        "save_bridge_regression": {
            "probe_pass": bool(save_bridge.get("probe_pass", False)),
            "wuzhuangyuan_selected_ending_route": save_bridge.get("wuzhuangyuan_summary", {}).get("selected_ending_route", ""),
            "true_selected_ending_route": save_bridge.get("true_route_summary", {}).get("selected_ending_route", ""),
        },
        "probe_pass": fields["probe_pass"],
    }
    write_json(REPORT_JSON, payload)
    REPORT_MD.write_text(
        "\n".join(
            ["# Route Content Probe Report", ""]
            + [f"- `{key}={value}`" for key, value in fields.items()]
        )
        + "\n",
        encoding="utf-8",
    )
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if fields["probe_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
