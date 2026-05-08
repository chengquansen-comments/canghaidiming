#!/usr/bin/env python3
"""v2.0 full package runtime readiness audit（只读评估）。"""

from __future__ import annotations

import csv
import os
import uuid
from pathlib import Path

OUT_TSV = Path("data/design/generated_full_package_runtime_readiness.tsv")
OUT_MD = Path("data/design/generated_full_package_runtime_blockers.md")

INPUT_COUNTS = {
    "battle_slot": (Path("data/runtime_preview/content_engine/battle_slots.preview.json"), "battle_slots"),
    "enemy_deck": (Path("data/runtime_preview/content_engine/enemy_decks.preview.json"), "enemy_decks"),
    "card_pool": (Path("data/runtime_preview/content_engine/card_pool.preview.json"), "cards"),
    "reward": (Path("data/runtime_preview/content_engine/battle_rewards.preview.json"), "rewards"),
    "operation_node": (Path("data/runtime_preview/content_engine/operation_nodes.preview.json"), "operation_nodes"),
    "narrative": (Path("data/runtime_preview/content_engine/narrative_nodes.preview.json"), "narrative_nodes"),
    "route_gate": (Path("data/runtime_preview/content_engine/route_gates.preview.json"), "route_gates"),
}

FIELDS = [
    "domain",
    "preview_available",
    "preview_count",
    "candidate_path_verified",
    "shadow_compare_verified",
    "runtime_schema_ready",
    "runtime_adapter_exists",
    "legacy_fallback_available",
    "formal_enable_ready",
    "required_runtime_adapter",
    "blocker_level",
    "blockers",
    "next_action",
    "notes",
]


def read_json(path: Path) -> dict:
    import json

    return json.loads(path.read_text(encoding="utf-8"))


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def atomic_write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{uuid.uuid4().hex}.tmp")
    with tmp.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{uuid.uuid4().hex}.tmp")
    with tmp.open("w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def main() -> int:
    candidate_rows = read_tsv(Path("data/design/generated_full_package_candidate_path_report.tsv"))
    shadow_rows = read_tsv(Path("data/design/generated_full_package_shadow_compare_report.tsv"))

    cand_ok = {r.get("domain", ""): (r.get("candidate_available") == "true") for r in candidate_rows}
    shadow_ok = {r.get("domain", ""): (r.get("candidate_available") == "true") for r in shadow_rows}

    domain_map = {
        "battle_slot": {
            "required_runtime_adapter": "battle_slot_runtime_loader",
            "runtime_adapter_exists": "false",
            "legacy_fallback_available": "true",
            "runtime_schema_ready": "true",
            "blockers": "缺 battle_slot 正式 runtime adapter 与流程挂接。",
            "next_action": "v2.1 实现 battle_slot runtime loader 与 legacy fallback 桥接。",
        },
        "enemy_deck": {
            "required_runtime_adapter": "enemy_deck_runtime_loader",
            "runtime_adapter_exists": "false",
            "legacy_fallback_available": "true",
            "runtime_schema_ready": "true",
            "blockers": "未证明 generated enemy_deck 可被正式战斗 enemy loader 使用。",
            "next_action": "v2.1 建立 enemy_deck runtime adapter 与 deck 绑定规则。",
        },
        "card_pool": {
            "required_runtime_adapter": "card_pool_to_card_data_mapper",
            "runtime_adapter_exists": "false",
            "legacy_fallback_available": "true",
            "runtime_schema_ready": "true",
            "blockers": "未证明可安全映射 CardData。",
            "next_action": "v2.1 增加 card_pool->CardData 只读映射与回退策略。",
        },
        "reward": {
            "required_runtime_adapter": "battle_reward_runtime_adapter",
            "runtime_adapter_exists": "true",
            "legacy_fallback_available": "true",
            "runtime_schema_ready": "true",
            "blockers": "shadow/candidate 已通，但正式 enable 仍未放开。",
            "next_action": "v2.1 在白名单下做受控正式接入评估。",
        },
        "operation_node": {
            "required_runtime_adapter": "operation_node_runtime_loader",
            "runtime_adapter_exists": "false",
            "legacy_fallback_available": "true",
            "runtime_schema_ready": "true",
            "blockers": "缺 operation node 正式流程挂接。",
            "next_action": "v2.1 设计 operation node adapter 与 legacy fallback。",
        },
        "narrative": {
            "required_runtime_adapter": "narrative_runtime_loader",
            "runtime_adapter_exists": "false",
            "legacy_fallback_available": "true",
            "runtime_schema_ready": "true",
            "blockers": "当前仅 key/hook，缺正文策略与正式挂接。",
            "next_action": "v2.1 定义 narrative runtime 字段与安全挂接边界。",
        },
        "route_gate": {
            "required_runtime_adapter": "route_gate_runtime_loader",
            "runtime_adapter_exists": "false",
            "legacy_fallback_available": "true",
            "runtime_schema_ready": "true",
            "blockers": "缺 route gate 正式路线逻辑挂接。",
            "next_action": "v2.1 增加 route gate adapter 与 fallback。",
        },
    }

    rows: list[dict[str, str]] = []
    for domain, (path, list_key) in INPUT_COUNTS.items():
        obj = read_json(path)
        cnt = len(obj.get(list_key, [])) if isinstance(obj.get(list_key, []), list) else 0
        runtime_adapter_exists = domain_map[domain]["runtime_adapter_exists"]
        formal_ready = "false"  # 本阶段统一不放开正式 enable
        blocker_level = "high" if runtime_adapter_exists == "false" else "medium"
        rows.append(
            {
                "domain": domain,
                "preview_available": "true",
                "preview_count": str(cnt),
                "candidate_path_verified": "true" if cand_ok.get(domain, False) else "false",
                "shadow_compare_verified": "true" if shadow_ok.get(domain, False) else "false",
                "runtime_schema_ready": domain_map[domain]["runtime_schema_ready"],
                "runtime_adapter_exists": runtime_adapter_exists,
                "legacy_fallback_available": domain_map[domain]["legacy_fallback_available"],
                "formal_enable_ready": formal_ready,
                "required_runtime_adapter": domain_map[domain]["required_runtime_adapter"],
                "blocker_level": blocker_level,
                "blockers": domain_map[domain]["blockers"],
                "next_action": domain_map[domain]["next_action"],
                "notes": "本次仅 readiness audit，不导出 runtime，不改正式流程。",
            }
        )

    atomic_write_tsv(OUT_TSV, rows)

    lines = [
        "# Full Package Runtime Readiness Blockers",
        "",
        "## 终局定义",
        "全生成内容（7 个 domain）正式 enable，并具备可回退的 runtime 挂接能力。",
        "",
        "## 当前状态",
    ]
    for r in rows:
        lines.append(f"- {r['domain']}: formal_enable_ready={r['formal_enable_ready']}，adapter={r['runtime_adapter_exists']}，blocker={r['blockers']}")
    lines.extend(
        [
            "",
            "## 缺 runtime adapter 的 domain",
            "- battle_slot, enemy_deck, card_pool, operation_node, narrative, route_gate",
            "",
            "## 缺 legacy fallback 的 domain",
            "- 当前审计未发现缺失项（均标记为可回退），但尚未完成正式 adapter 级联验证。",
            "",
            "## 缺正式流程挂接的 domain",
            "- battle_slot, enemy_deck, card_pool, operation_node, narrative, route_gate",
            "",
            "## v2.1 推荐优先项",
            "1. card_pool_to_card_data_mapper",
            "2. enemy_deck_runtime_loader",
            "3. battle_slot_runtime_loader",
            "4. operation_node_runtime_loader / route_gate_runtime_loader",
            "5. narrative_runtime_loader（含正文策略）",
            "",
            "## 说明",
            "本次仅 readiness audit，没有导出 runtime，也没有改 Godot 正式流程。",
            "",
        ]
    )
    atomic_write_text(OUT_MD, "\n".join(lines))
    print(f"Wrote {OUT_TSV.as_posix()} and {OUT_MD.as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
