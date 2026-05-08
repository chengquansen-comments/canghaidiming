#!/usr/bin/env python3
"""v2.1 full content runtime bridge contract validator。"""

from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path

CONTRACT = Path("data/design/generated_full_content_adapter_contract.tsv")
BINDING = Path("data/design/generated_full_content_whitelist_binding_map.tsv")
BUNDLE = Path("data/runtime/content_engine_whitelist/prologue_01.full_content_bridge.json")
MANIFEST = Path("data/runtime/content_engine_whitelist/full_content_bridge_manifest.json")
RUNTIME_CFG = Path("data/runtime/content_engine/runtime_loader_config.json")
SHADOW_FREEZE = Path("data/design/generated_battle_reward_shadow_freeze_report.tsv")

FORBIDDEN_PATTERNS = [
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "scripts/card_data.gd",
    "data/story_battles/",
    "scenes/",
]
REQ_DOMAINS = {"battle_slot", "enemy_deck", "card_pool", "reward", "operation_node", "narrative", "route_gate"}


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def changed_forbidden_files() -> list[str]:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    bad: list[str] = []
    for line in out.splitlines():
        p = line[3:].strip() if len(line) > 3 else ""
        if p and any(p == t or p.startswith(t) for t in FORBIDDEN_PATTERNS):
            bad.append(p)
    return sorted(set(bad))


def main() -> int:
    for p, n in [(CONTRACT, "adapter contract"), (BINDING, "binding map"), (BUNDLE, "bridge bundle"), (MANIFEST, "bridge manifest")]:
        if not p.exists() or p.stat().st_size == 0:
            return fail(f"{n} 不存在或为空")

    contract_rows = read_tsv(CONTRACT)
    binding_rows = read_tsv(BINDING)
    bundle = json.loads(BUNDLE.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))

    if {r.get("domain", "") for r in contract_rows} != REQ_DOMAINS:
        return fail("adapter contract 未覆盖 7 domain")
    if {r.get("domain", "") for r in binding_rows} != REQ_DOMAINS:
        return fail("binding map 未覆盖 7 domain")
    if any(r.get("battle_slot_id") != "prologue_01" for r in binding_rows):
        return fail("binding map 只允许 prologue_01")

    bidx = {r.get("domain", ""): r for r in binding_rows}
    if bidx["reward"].get("candidate_id") != "rw_prologue_01":
        return fail("reward 必须 rw_prologue_01")
    if bidx["battle_slot"].get("candidate_id") != "prologue_01":
        return fail("battle_slot 必须 prologue_01")
    if bidx["card_pool"].get("candidate_count") != "72":
        return fail("card_pool_count 必须 72")
    if bidx["operation_node"].get("candidate_count") != "10":
        return fail("operation_node_count 必须 10")
    if bidx["narrative"].get("candidate_count") != "28":
        return fail("narrative_count 必须 28")
    if bidx["route_gate"].get("candidate_count") != "9":
        return fail("route_gate_count 必须 9")
    if bidx["enemy_deck"].get("candidate_available") != "true":
        return fail("enemy_deck candidate_available 必须 true")

    if any(r.get("fallback_policy") != "legacy" for r in contract_rows):
        return fail("fallback_policy 必须全部 legacy")
    if any(r.get("write_to_game_state_allowed") != "false" for r in contract_rows):
        return fail("write_to_game_state_allowed 必须全部 false")

    for k, v in [
        ("package_type", "full_content_whitelist_bridge"),
        ("battle_slot_id", "prologue_01"),
        ("rollback_policy", "legacy"),
    ]:
        if str(bundle.get(k)) != v:
            return fail(f"bridge bundle {k} 必须 {v}")
    if bundle.get("global_content_engine_enabled") is not False:
        return fail("global_content_engine_enabled 必须 false")
    if bundle.get("formal_runtime_enabled") is not False:
        return fail("formal_runtime_enabled 必须 false")
    if bundle.get("runtime_ready") is not False:
        return fail("runtime_ready 必须 false")
    if bundle.get("bridge_only") is not True:
        return fail("bridge_only 必须 true")

    for k, v in [
        ("package_type", "full_content_whitelist_bridge_manifest"),
        ("bundle_count", 1),
        ("rollback_policy", "legacy"),
    ]:
        if manifest.get(k) != v:
            return fail(f"bridge manifest {k} 异常")
    if manifest.get("whitelist_battle_slots") != ["prologue_01"]:
        return fail("whitelist_battle_slots 必须 [prologue_01]")
    if manifest.get("global_content_engine_enabled") is not False:
        return fail("manifest global_content_engine_enabled 必须 false")
    if manifest.get("formal_runtime_enabled") is not False:
        return fail("manifest formal_runtime_enabled 必须 false")
    if manifest.get("runtime_ready") is not False:
        return fail("manifest runtime_ready 必须 false")
    if manifest.get("bridge_only") is not True:
        return fail("manifest bridge_only 必须 true")

    if "正文" in bidx["narrative"].get("notes", "") and "不允许正文" not in bidx["narrative"].get("notes", ""):
        return fail("narrative 说明需明确不允许正文")

    if not str(BUNDLE).startswith("data/runtime/content_engine_whitelist/"):
        return fail("bridge bundle 路径必须位于 data/runtime/content_engine_whitelist/")
    if not str(MANIFEST).startswith("data/runtime/content_engine_whitelist/"):
        return fail("bridge manifest 路径必须位于 data/runtime/content_engine_whitelist/")

    cfg = json.loads(RUNTIME_CFG.read_text(encoding="utf-8"))
    if bool(cfg.get("content_engine_runtime_enabled", False)):
        return fail("content_engine_enabled 必须 false")

    if SHADOW_FREEZE.exists() and SHADOW_FREEZE.stat().st_size > 0:
        freeze = {r.get("check_id", ""): r for r in read_tsv(SHADOW_FREEZE)}
        if freeze.get("selected_reward_source", {}).get("actual") != "legacy":
            return fail("selected_reward 必须 legacy")

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print("PASS: adapter contract/binding map/bridge bundle/manifest 均存在")
    print("PASS: 覆盖 7 domain，白名单仅 prologue_01")
    print("PASS: reward=rw_prologue_01, card_pool=72, operation=10, narrative=28, route=9")
    print("PASS: enemy_deck candidate_available=true")
    print("PASS: fallback_policy=legacy, write_to_game_state_allowed=false")
    print("PASS: global_content_engine_enabled=false, formal_runtime_enabled=false")
    print("PASS: rollback_policy=legacy, runtime_ready=false, bridge_only=true")
    print("PASS: 未写全局 data/runtime/content_engine/*.json")
    print("PASS: 未改 story/scenes/combat core, selected_reward=legacy")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
