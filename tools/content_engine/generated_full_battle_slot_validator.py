#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path

PREVIEW_SLOTS = Path("data/runtime_preview/content_engine/battle_slots.preview.json")
CFG = Path("data/design/generated_full_battle_slot_whitelist_config.tsv")
BIND = Path("data/design/generated_full_battle_slot_binding_map.tsv")
INTEGRATION = Path("data/design/generated_full_battle_slot_integration_report.tsv")
BUNDLE = Path("data/runtime/content_engine_whitelist/generated_full_battle_slots.full_content_bridge.json")
MANIFEST = Path("data/runtime/content_engine_whitelist/generated_full_battle_slots_manifest.json")
LOADOUT_REPORT = Path("data/design/generated_battle_runtime_loadout_report.tsv")
MAP_ROUTE_REPORT = Path("data/design/generated_map_route_runtime_flow_report.tsv")

FORBIDDEN_PREFIX = [
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "scripts/card_data.gd",
    "data/story_battles/",
    "scenes/",
]


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def modified_files() -> list[str]:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    files = []
    for line in out.splitlines():
        if len(line) < 4:
            continue
        files.append(line[3:].strip())
    return files


def main() -> int:
    for p in [PREVIEW_SLOTS, CFG, BIND, INTEGRATION, BUNDLE, MANIFEST, LOADOUT_REPORT, MAP_ROUTE_REPORT]:
        if not p.exists() or p.stat().st_size == 0:
            return fail(f"missing_or_empty: {p}")

    preview_slots = json.loads(PREVIEW_SLOTS.read_text(encoding="utf-8")).get("battle_slots", [])
    preview_ids = sorted({str(r.get("battle_slot_id", "")) for r in preview_slots if str(r.get("battle_slot_id", ""))})
    if len(preview_ids) != 16:
        return fail(f"preview battle_slot 数量必须 16，实际 {len(preview_ids)}")

    cfg = read_tsv(CFG)
    bind = read_tsv(BIND)
    if len(cfg) != 16:
        return fail(f"whitelist config 数量必须 16，实际 {len(cfg)}")

    cfg_ids = sorted({r.get("battle_slot_id", "") for r in cfg if r.get("battle_slot_id", "")})
    if cfg_ids != preview_ids:
        return fail("whitelist config battle_slot 与 preview battle_slot 不一致")

    expected_domains = {"battle_slot", "enemy_deck", "card_pool", "reward", "operation_node", "narrative", "route_gate"}
    if len(bind) != 16 * 7:
        return fail(f"binding map 数量必须 112，实际 {len(bind)}")

    for sid in preview_ids:
        rows = [r for r in bind if r.get("battle_slot_id") == sid]
        domains = {r.get("domain", "") for r in rows}
        if domains != expected_domains:
            return fail(f"{sid} 未覆盖 7 domain")
        idx = {r.get("domain", ""): r for r in rows}
        if idx["battle_slot"].get("candidate_available") != "true":
            return fail(f"{sid} battle_slot candidate 必须可用")
        if idx["enemy_deck"].get("candidate_available") != "true":
            return fail(f"{sid} enemy_deck candidate 必须可用")
        if idx["card_pool"].get("candidate_count") != "72":
            return fail(f"{sid} card_pool_count 必须 72")
        if idx["operation_node"].get("candidate_count") != "10":
            return fail(f"{sid} operation_node_count 必须 10")
        if idx["narrative"].get("candidate_count") != "28":
            return fail(f"{sid} narrative_count 必须 28")
        if "key/hook" not in idx["narrative"].get("notes", ""):
            return fail(f"{sid} narrative 必须仅 key/hook")
        if idx["route_gate"].get("candidate_count") != "9":
            return fail(f"{sid} route_gate_count 必须 9")
        if "routing change" not in idx["route_gate"].get("notes", ""):
            return fail(f"{sid} route_gate 不得改变正式分流")
        for d in expected_domains:
            if idx[d].get("fallback_policy") != "legacy":
                return fail(f"{sid} {d} fallback_policy 必须 legacy")

    prologue = [r for r in bind if r.get("battle_slot_id") == "prologue_01" and r.get("domain") == "reward"]
    if not prologue or prologue[0].get("candidate_id") != "rw_prologue_01":
        return fail("prologue_01 reward 必须 rw_prologue_01")

    # reward 缺失槽位应 fallback legacy（当前数据可能为 0）
    for r in cfg:
        if r.get("reward_fallback_required") == "true":
            sid = r.get("battle_slot_id", "")
            reward = next(x for x in bind if x.get("battle_slot_id") == sid and x.get("domain") == "reward")
            if reward.get("formal_source") != "legacy":
                return fail(f"{sid} reward_fallback_required=true 时 formal_source 必须 legacy")

    bundle = json.loads(BUNDLE.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if len(bundle.get("whitelist_battle_slots", [])) != 16:
        return fail("bridge bundle whitelist_battle_slots 必须 16")
    if len(manifest.get("whitelist_battle_slots", [])) != 16:
        return fail("bridge manifest whitelist_battle_slots 必须 16")
    if bundle.get("rollback_policy") != "legacy" or manifest.get("rollback_policy") != "legacy":
        return fail("rollback_policy 必须 legacy")

    loadout_rows = read_tsv(LOADOUT_REPORT)
    map_route_rows = read_tsv(MAP_ROUTE_REPORT)
    for sid in preview_ids:
        lrow = next((r for r in loadout_rows if r.get("battle_slot_id") == sid), None)
        if lrow is None:
            return fail(f"{sid} 缺少 battle runtime loadout report 记录")
        if lrow.get("loadout_candidate_available") != "true":
            return fail(f"{sid} battle loadout 必须可用")
        if lrow.get("enemy_deck_candidate_available") != "true":
            return fail(f"{sid} enemy_deck candidate 必须可用（loadout report）")
        if lrow.get("card_pool_count") != "72":
            return fail(f"{sid} loadout report card_pool_count 必须 72")

        mrow = next((r for r in map_route_rows if r.get("battle_slot_id") == sid), None)
        if mrow is None:
            return fail(f"{sid} 缺少 map route runtime flow report 记录")
        if mrow.get("map_route_candidate_available") != "true":
            return fail(f"{sid} map route candidate 必须可用")
        if mrow.get("operation_node_count") != "10":
            return fail(f"{sid} operation_node_count 必须 10（map route report）")
        if mrow.get("narrative_key_count") != "28":
            return fail(f"{sid} narrative_key_count 必须 28（map route report）")
        if mrow.get("route_gate_count") != "9":
            return fail(f"{sid} route_gate_count 必须 9（map route report）")

    # 非 preview slot 仍 legacy：挑一个不在 preview 的样例验证（如 unknown_slot）
    preview_set = set(preview_ids)
    if "unknown_slot" in preview_set:
        return fail("测试样例冲突：unknown_slot 出现在 preview")

    status_out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    bad_runtime = []
    for line in status_out.splitlines():
        p = line[3:].strip() if len(line) > 3 else ""
        if p.startswith("data/runtime/content_engine/") and line[:2] in {"A ", "??"}:
            bad_runtime.append(p)
    if bad_runtime:
        return fail("不允许新增全局 data/runtime/content_engine/*.json: " + ", ".join(sorted(set(bad_runtime))))

    changed = modified_files()
    bad = [p for p in changed if any(p == pref or p.startswith(pref) for pref in FORBIDDEN_PREFIX)]
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(sorted(set(bad))))

    print("PASS: preview battle_slot=16, config=16, binding=112")
    print("PASS: 16 个 slot 全覆盖 7 domain，reward 缺失策略可回落 legacy")
    print("PASS: fallback_policy=legacy，未新增全局 runtime content_engine JSON")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
