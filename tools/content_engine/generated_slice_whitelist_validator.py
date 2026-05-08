#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path

CFG = Path("data/design/generated_slice_whitelist_config.tsv")
BIND = Path("data/design/generated_slice_whitelist_binding_map.tsv")
ACCEPT = Path("data/design/generated_slice_whitelist_acceptance_report.tsv")
BUNDLE = Path("data/runtime/content_engine_whitelist/generated_slice.full_content_bridge.json")
MANIFEST = Path("data/runtime/content_engine_whitelist/generated_slice_manifest.json")

FORBIDDEN_PATTERNS = [
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


def changed_forbidden_files() -> list[str]:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    bad = []
    for line in out.splitlines():
        p = line[3:].strip() if len(line) > 3 else ""
        if p and any(p == t or p.startswith(t) for t in FORBIDDEN_PATTERNS):
            bad.append(p)
    return sorted(set(bad))


def main() -> int:
    for p in [CFG, BIND, ACCEPT, BUNDLE, MANIFEST]:
        if not p.exists() or p.stat().st_size == 0:
            return fail(f"missing_or_empty: {p}")

    cfg = read_tsv(CFG)
    bind = read_tsv(BIND)
    if not any(r.get("battle_slot_id") == "prologue_01" for r in cfg):
        return fail("config 必须包含 prologue_01")

    slots = sorted({r.get("battle_slot_id", "") for r in cfg if r.get("battle_slot_id", "")})
    domains = {"battle_slot", "enemy_deck", "card_pool", "reward", "operation_node", "narrative", "route_gate"}
    for s in slots:
        dset = {r.get("domain", "") for r in bind if r.get("battle_slot_id") == s}
        if dset != domains:
            return fail(f"{s} 未覆盖 7 domain")

    p_rows = [r for r in bind if r.get("battle_slot_id") == "prologue_01"]
    pidx = {r.get("domain", ""): r for r in p_rows}
    if pidx["reward"].get("candidate_id") != "rw_prologue_01":
        return fail("prologue_01 reward 必须 rw_prologue_01")
    if pidx["card_pool"].get("candidate_count") != "72":
        return fail("card_pool_count 必须 72")
    if pidx["operation_node"].get("candidate_count") != "10":
        return fail("operation_node_count 必须 10")
    if pidx["narrative"].get("candidate_count") != "28":
        return fail("narrative_count 必须 28")
    if "key/hook" not in pidx["narrative"].get("notes", ""):
        return fail("narrative 必须仅 key/hook")
    if pidx["route_gate"].get("candidate_count") != "9":
        return fail("route_gate_count 必须 9")
    if "routing change" not in pidx["route_gate"].get("notes", ""):
        return fail("route_gate 不得改变正式分流")

    for r in bind:
        if r.get("fallback_policy") != "legacy":
            return fail("fallback_policy 必须 legacy")

    bundle = json.loads(BUNDLE.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if bundle.get("rollback_policy") != "legacy":
        return fail("bundle rollback_policy 必须 legacy")
    if manifest.get("rollback_policy") != "legacy":
        return fail("manifest rollback_policy 必须 legacy")

    status_out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    added_runtime = []
    for line in status_out.splitlines():
        p = line[3:].strip() if len(line) > 3 else ""
        if p.startswith("data/runtime/content_engine/") and line[:2] in {"A ", "??"}:
            added_runtime.append(p)
    if added_runtime:
        return fail("不允许新增全局 data/runtime/content_engine/*.json: " + ", ".join(sorted(set(added_runtime))))

    bad = changed_forbidden_files()
    if bad:
        return fail("检测到禁止修改文件: " + ", ".join(bad))

    print(f"PASS: whitelist slots={len(slots)}")
    print("PASS: prologue_01 reward/card_pool/operation/narrative/route_gate 校验通过")
    print("PASS: fallback_policy=legacy，未改核心风险文件")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
