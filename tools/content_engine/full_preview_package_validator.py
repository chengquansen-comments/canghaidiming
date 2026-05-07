#!/usr/bin/env python3
"""v1.6 full preview package validator。"""

from __future__ import annotations

import json
from pathlib import Path

BASE = Path("data/runtime_preview/content_engine")

FILES = {
    "battle_rewards": BASE / "battle_rewards.preview.json",
    "battle_slots": BASE / "battle_slots.preview.json",
    "enemy_decks": BASE / "enemy_decks.preview.json",
    "card_pool": BASE / "card_pool.preview.json",
    "operation_nodes": BASE / "operation_nodes.preview.json",
    "narrative_nodes": BASE / "narrative_nodes.preview.json",
    "route_gates": BASE / "route_gates.preview.json",
}

FULL_MANIFEST = BASE / "full_content_package.preview_manifest.json"
FORBIDDEN_FORMAL_RUNTIME_FILE = Path("data/runtime/content_engine/battle_rewards.json")

EXPECTED_COUNTS = {
    "battle_rewards": 45,
    "enemy_decks": 39,
    "card_pool": 72,
    "operation_nodes": 10,
    "narrative_nodes": 28,
    "route_gates": 9,
}


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    for name, path in FILES.items():
        if not path.exists():
            return fail(f"missing preview json: {name}")

    if not FULL_MANIFEST.exists():
        return fail("missing full preview manifest")

    payloads = {name: load_json(path) for name, path in FILES.items()}
    manifest = load_json(FULL_MANIFEST)

    for name, obj in payloads.items():
        if obj.get("runtime_ready") is not False:
            return fail(f"{name}: runtime_ready must be false")
        if obj.get("preview_only") is not True:
            return fail(f"{name}: preview_only must be true")
        if obj.get("selected_reward_policy") != "legacy":
            return fail(f"{name}: selected_reward_policy must be legacy")

    if manifest.get("runtime_ready") is not False:
        return fail("manifest runtime_ready must be false")
    if manifest.get("preview_only") is not True:
        return fail("manifest preview_only must be true")
    if manifest.get("selected_reward_policy") != "legacy":
        return fail("manifest selected_reward_policy must be legacy")
    if manifest.get("content_engine_enabled") is True:
        return fail("content_engine_enabled must not be true")

    domains = manifest.get("domains", [])
    if not isinstance(domains, list) or len(domains) != 7:
        return fail("full manifest domains must be 7")

    if FORBIDDEN_FORMAL_RUNTIME_FILE.exists():
        return fail("forbidden formal runtime file exists: data/runtime/content_engine/battle_rewards.json")

    rewards = payloads["battle_rewards"].get("rewards", [])
    enemy_decks = payloads["enemy_decks"].get("enemy_decks", [])
    cards = payloads["card_pool"].get("cards", [])
    op_nodes = payloads["operation_nodes"].get("operation_nodes", [])
    nar_nodes = payloads["narrative_nodes"].get("narrative_nodes", [])
    route_gates = payloads["route_gates"].get("route_gates", [])
    battle_slots = payloads["battle_slots"].get("battle_slots", [])

    got_counts = {
        "battle_rewards": len(rewards),
        "enemy_decks": len(enemy_decks),
        "card_pool": len(cards),
        "operation_nodes": len(op_nodes),
        "narrative_nodes": len(nar_nodes),
        "route_gates": len(route_gates),
    }
    for k, expected in EXPECTED_COUNTS.items():
        if got_counts[k] != expected:
            return fail(f"{k} count expected {expected}, got {got_counts[k]}")

    if len(battle_slots) <= 0:
        return fail("battle_slots must be non-empty")

    joined = json.dumps(payloads["narrative_nodes"], ensure_ascii=False)
    forbidden_tokens = ["full_text", "body", "dialogue", "content_text", "正文"]
    if any(tok in joined for tok in forbidden_tokens):
        return fail("narrative preview must not include formal body text")

    print("PASS: 7 个 preview JSON 全存在")
    print("PASS: full manifest 存在")
    print("PASS: runtime_ready 全部 false")
    print("PASS: preview_only 全部 true")
    print("PASS: 未写 data/runtime/content_engine/battle_rewards.json")
    print("PASS: reward=45 enemy_decks=39 card_pool=72 operation_nodes=10 narrative_nodes=28 route_gates=9")
    print("PASS: battle_slots 非空")
    print("PASS: narrative 不包含正式正文")
    print("PASS: content_engine_enabled 非 true")
    print("PASS: selected_reward_policy=legacy")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
