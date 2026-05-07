#!/usr/bin/env python3
"""静态扫描 battle_reward 旧奖励流程候选并产出定位报告。"""

from __future__ import annotations

import argparse
import csv
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


REPORT_TSV = Path("data/design/generated_battle_reward_legacy_flow_report.tsv")
REPORT_MD = Path("data/design/generated_battle_reward_legacy_flow_report.md")
SCAN_ROOTS = [Path("scripts"), Path("data"), Path("scenes")]
TEXT_SUFFIX_ALLOWLIST = {
    ".gd",
    ".json",
    ".tsv",
    ".csv",
    ".md",
    ".txt",
    ".cfg",
    ".tscn",
    ".tres",
    ".gdshader",
    ".shader",
}
HIGH_RISK_EXACT = {
    "scripts/combat_resolver.gd",
    "scripts/battle_state_machine.gd",
    "scripts/card_data.gd",
}
KEYWORDS = [
    "reward",
    "rewards",
    "battle_reward",
    "奖励",
    "settlement",
    "loot",
    "drop",
    "gain",
    "card_reward",
    "choose_reward",
    "result",
    "victory",
    "clear",
    "battle_end",
    "战斗结算",
    "结算",
    "掉落",
    "获得",
]
FIELDS = [
    "candidate_type",
    "file_path",
    "symbol_or_line",
    "matched_keyword",
    "evidence",
    "likely_role",
    "confidence",
    "risk_level",
    "recommended_action",
    "notes",
]
CANDIDATE_TYPES = {
    "legacy_reward_source",
    "reward_generation_function",
    "battle_settlement_entry",
    "reward_display_entry",
    "reward_apply_entry",
    "debug_or_test_entry",
    "high_risk_touchpoint",
    "unknown_candidate",
}
CONFIDENCE_VALUES = {"high", "medium", "low"}
RISK_VALUES = {"low", "medium", "high"}
WEAK_KEYWORDS = {"result", "clear", "gain", "victory"}
STRONG_CONTEXT_TOKENS = {
    "reward",
    "battle_reward",
    "奖励",
    "settlement",
    "loot",
    "drop",
    "card_reward",
    "choose_reward",
    "battle_end",
    "战斗结算",
    "结算",
    "掉落",
    "获得",
}
MINIMAL_INTEGRATION_HINTS = {
    "scripts/narrative_demo_canonical_controller.gd::_battle_reward_for_source",
    "scripts/narrative_demo_canonical_controller.gd::_apply_battle_result_reward",
    "scripts/battle_controller_visual_story_return.gd::_on_battle_result_confirm_pressed",
}
SEED_SPECS = [
    {"path": "data/rewards.json", "symbol": "line:1", "keyword": "reward", "needle": ""},
    {"path": "scripts/battle_controller_core_catalog.gd", "symbol": "reward_pool", "keyword": "reward", "needle": "reward_pool = ["},
    {"path": "scripts/battle_controller_core_round_resolution.gd", "symbol": "_finish_battle", "keyword": "battle_end", "needle": "func _finish_battle()"},
    {"path": "scripts/battle_controller_visual_story_return.gd", "symbol": "_show_battle_result_overlay", "keyword": "result", "needle": "func _show_battle_result_overlay"},
    {"path": "scripts/battle_controller_visual_story_return.gd", "symbol": "_on_battle_result_confirm_pressed", "keyword": "result", "needle": "func _on_battle_result_confirm_pressed"},
    {"path": "scripts/narrative_battle_context.gd", "symbol": "grant_player_cards", "keyword": "reward", "needle": "static func grant_player_cards"},
    {"path": "scripts/narrative_battle_context.gd", "symbol": "apply_player_growth", "keyword": "reward", "needle": "static func apply_player_growth"},
    {"path": "scripts/narrative_demo_canonical_controller.gd", "symbol": "_battle_reward_for_source", "keyword": "battle_reward", "needle": "func _battle_reward_for_source"},
]


@dataclass
class Candidate:
    candidate_type: str
    file_path: str
    symbol_or_line: str
    matched_keyword: str
    evidence: str
    likely_role: str
    confidence: str
    risk_level: str
    recommended_action: str
    notes: str

    def to_row(self) -> dict[str, str]:
        return {
            "candidate_type": self.candidate_type,
            "file_path": self.file_path,
            "symbol_or_line": self.symbol_or_line,
            "matched_keyword": self.matched_keyword,
            "evidence": self.evidence,
            "likely_role": self.likely_role,
            "confidence": self.confidence,
            "risk_level": self.risk_level,
            "recommended_action": self.recommended_action,
            "notes": self.notes,
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="扫描旧奖励流程候选并输出 TSV/Markdown 报告。")
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    parser.add_argument("--max-per-file", type=int, default=8)
    return parser.parse_args()


def is_probably_text(path: Path) -> bool:
    if path.suffix.lower() not in TEXT_SUFFIX_ALLOWLIST:
        return False
    try:
        if path.stat().st_size > 2 * 1024 * 1024:
            return False
    except FileNotFoundError:
        return False
    return True


def iter_scan_files() -> list[Path]:
    result: list[Path] = []
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.is_file() and is_probably_text(path):
                result.append(path)
    return sorted(result)


def extract_symbol(line: str, line_no: int) -> str:
    func_match = re.match(r"\s*(?:static\s+)?func\s+([A-Za-z0-9_]+)\s*\(", line)
    if func_match:
        return func_match.group(1)
    var_match = re.match(r"\s*(?:const|var)\s+([A-Za-z0-9_]+)", line)
    if var_match:
        return var_match.group(1)
    return f"line:{line_no}"


def match_keyword(line: str) -> str:
    lower = line.lower()
    for keyword in KEYWORDS:
        if keyword.isascii():
            pattern = rf"(?<![0-9a-z]){re.escape(keyword)}(?![0-9a-z])"
            if re.search(pattern, lower):
                return keyword
        else:
            if keyword in line:
                return keyword
    return ""


def should_skip_weak_match(path: str, line: str, keyword: str) -> bool:
    if keyword not in WEAK_KEYWORDS:
        return False
    lower = line.lower()
    has_strong = any(token in lower or token in line for token in STRONG_CONTEXT_TOKENS)
    curated_paths = (
        "battle_controller_visual_story_return.gd",
        "battle_controller_core_session_rewards.gd",
        "narrative_demo_formal_controller.gd",
        "narrative_demo_canonical_controller.gd",
        "narrative_battle_context.gd",
        "battle_context_bridge.gd",
        "safe_demo_runtime.gd",
        "data/rewards.json",
        "data/enemy_manifest.json",
    )
    if has_strong:
        return False
    if path.startswith("data/") and keyword in {"result", "gain"} and "reward" not in lower and "奖励" not in line:
        return True
    return not any(path.endswith(x) for x in curated_paths)


def is_high_risk_path(path: str) -> bool:
    if path in HIGH_RISK_EXACT:
        return True
    if path.startswith("data/story_battles/") and path.endswith(".tsv"):
        return True
    if path.startswith("scenes/") and path.endswith(".tscn"):
        return True
    return False


def classify(path: str, symbol: str, line: str, keyword: str) -> Candidate:
    low = line.lower()
    signature = f"{path}::{symbol}"

    if is_high_risk_path(path):
        return Candidate(
            candidate_type="high_risk_touchpoint",
            file_path=path,
            symbol_or_line=symbol,
            matched_keyword=keyword,
            evidence=line.strip(),
            likely_role="不建议直接修改的高风险文件触点",
            confidence="high",
            risk_level="high",
            recommended_action="保持只读，避免在 v1.0a 修改该文件。",
            notes="主流程关键文件，当前阶段仅允许静态定位。",
        )

    if (
        path == "data/rewards.json"
        or path == "data/enemy_manifest.json"
        or path == "data/story_battles.json"
        or "_formal_reward_for_encounter" in low
        or ("reward_pool" in low and ("_load_json_file" in low or "_ready_card(" in low))
        or ('"reward"' in low and "enemy_config" in low)
    ):
        return Candidate(
            candidate_type="legacy_reward_source",
            file_path=path,
            symbol_or_line=symbol,
            matched_keyword=keyword,
            evidence=line.strip(),
            likely_role="可能是旧奖励数据源",
            confidence="high" if path.startswith("data/") else "medium",
            risk_level="medium",
            recommended_action="纳入 adapter 的 legacy 读取分支，不直接改写原源数据。",
            notes="可作为 shadow 对比基线。",
        )

    if symbol in {
        "_sample_rewards",
        "_sample_battle_reward_choices",
        "_battle_reward_for_source",
        "_battle_growth_reward_for_source",
        "_formal_reward_for_encounter",
    } or "reward_from_context_or_node" in low or "growth_reward(" in low:
        notes = ""
        confidence = "medium"
        if signature in MINIMAL_INTEGRATION_HINTS:
            notes = "最小接入点候选：建议将 runtime/legacy 决策集中到该链路前。"
            confidence = "high"
        return Candidate(
            candidate_type="reward_generation_function",
            file_path=path,
            symbol_or_line=symbol,
            matched_keyword=keyword,
            evidence=line.strip(),
            likely_role="可能是奖励生成逻辑",
            confidence=confidence,
            risk_level="medium",
            recommended_action="后续由单一 adapter 接管奖励生成输入，函数保持调用层稳定。",
            notes=notes or "需区分卡牌奖励与叙事资源奖励两条链路。",
        )

    if symbol in {
        "_finish_battle",
        "_queue_battle_result_overlay",
        "_consume_battle_result_if_needed",
        "set_result",
        "_return_to_story_encounter_selection_after_battle",
    }:
        return Candidate(
            candidate_type="battle_settlement_entry",
            file_path=path,
            symbol_or_line=symbol,
            matched_keyword=keyword,
            evidence=line.strip(),
            likely_role="可能是战斗结束结算入口",
            confidence="high",
            risk_level="high" if path in HIGH_RISK_EXACT else "medium",
            recommended_action="避免直接改动结算主流程，在外层增加可控接入点。",
            notes="优先采用旁路接入和结果对比，降低回归风险。",
        )

    if symbol in {
        "_show_battle_result_overlay",
        "_open_gain_move",
        "_open_realm_move_reward",
        "_select_battle_reward_card",
        "_build_battle_result_layer",
    }:
        return Candidate(
            candidate_type="reward_display_entry",
            file_path=path,
            symbol_or_line=symbol,
            matched_keyword=keyword,
            evidence=line.strip(),
            likely_role="可能是奖励展示逻辑",
            confidence="high",
            risk_level="medium",
            recommended_action="保持 UI 展示层不感知 runtime 细节，只接收统一奖励结果。",
            notes="展示层可用于 shadow 信息透出，但不改变正式奖励写入。",
        )

    if symbol in {
        "_pick_reward_card",
        "_apply_battle_result_reward",
        "apply_battle_result_reward",
        "grant_player_cards",
        "apply_player_growth",
        "_grant_martial_rewards_between",
    }:
        return Candidate(
            candidate_type="reward_apply_entry",
            file_path=path,
            symbol_or_line=symbol,
            matched_keyword=keyword,
            evidence=line.strip(),
            likely_role="可能是奖励写入玩家状态逻辑",
            confidence="high",
            risk_level="medium",
            recommended_action="adapter 输出标准奖励结构后，通过单一应用入口落地。",
            notes="要求 adapter 失败不影响该入口的 legacy 执行。",
        )

    if (
        path.startswith("scripts/Main_")
        or "demo" in path
        or "debug" in low
        or "战斗测试" in line
        or "mock" in low
    ):
        return Candidate(
            candidate_type="debug_or_test_entry",
            file_path=path,
            symbol_or_line=symbol,
            matched_keyword=keyword,
            evidence=line.strip(),
            likely_role="可能是测试战斗或 debug 入口",
            confidence="medium",
            risk_level="low",
            recommended_action="runtime_test 模式仅允许从这类入口显式启用。",
            notes="可作为 runtime_test 白名单入口。",
        )

    return Candidate(
        candidate_type="unknown_candidate",
        file_path=path,
        symbol_or_line=symbol,
        matched_keyword=keyword,
        evidence=line.strip(),
        likely_role="可能只是 UI 文案或无关匹配",
        confidence="low",
        risk_level="low",
        recommended_action="保留观察，不作为首批接入点。",
        notes="后续按上下文二次人工筛选。",
    )


def collect_candidates(max_per_file: int) -> list[Candidate]:
    candidates: list[Candidate] = []
    per_file_count: dict[str, int] = defaultdict(int)

    for path in iter_scan_files():
        rel = path.as_posix()
        try:
            lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
        except OSError:
            continue
        current_func = ""
        for idx, line in enumerate(lines, start=1):
            func_match = re.match(r"\s*(?:static\s+)?func\s+([A-Za-z0-9_]+)\s*\(", line)
            if func_match:
                current_func = func_match.group(1)
            keyword = match_keyword(line)
            if not keyword:
                continue
            if should_skip_weak_match(rel, line, keyword):
                continue
            if per_file_count[rel] >= max_per_file:
                continue
            symbol = current_func or extract_symbol(line, idx)
            candidate = classify(rel, symbol, line, keyword)
            if candidate.candidate_type not in CANDIDATE_TYPES:
                continue
            if candidate.confidence not in CONFIDENCE_VALUES or candidate.risk_level not in RISK_VALUES:
                continue
            if candidate.symbol_or_line.startswith("line:"):
                candidate.symbol_or_line = f"line:{idx}"
            candidates.append(candidate)
            per_file_count[rel] += 1

    # 去重，避免同文件同符号重复噪音。
    dedup: dict[tuple[str, str, str, str], Candidate] = {}
    priority = {
        "high_risk_touchpoint": 7,
        "legacy_reward_source": 6,
        "battle_settlement_entry": 5,
        "reward_generation_function": 4,
        "reward_apply_entry": 3,
        "reward_display_entry": 2,
        "debug_or_test_entry": 1,
        "unknown_candidate": 0,
    }
    for item in candidates:
        key = (item.candidate_type, item.file_path, item.symbol_or_line, item.matched_keyword)
        old = dedup.get(key)
        if old is None or priority[item.candidate_type] >= priority[old.candidate_type]:
            dedup[key] = item

    for item in seed_candidates():
        key = (item.candidate_type, item.file_path, item.symbol_or_line, item.matched_keyword)
        if key not in dedup:
            dedup[key] = item

    return sorted(
        dedup.values(),
        key=lambda x: (
            -priority.get(x.candidate_type, 0),
            x.file_path,
            x.symbol_or_line,
            x.matched_keyword,
        ),
    )


def seed_candidates() -> list[Candidate]:
    seeded: list[Candidate] = []
    for spec in SEED_SPECS:
        path = Path(spec["path"])
        if not path.exists():
            continue
        rel = path.as_posix()
        text = path.read_text(encoding="utf-8", errors="ignore")
        lines = text.splitlines() or [""]
        needle = str(spec["needle"])
        line_text = lines[0]
        for line in lines:
            if needle and needle in line:
                line_text = line
                break
        symbol = str(spec["symbol"])
        keyword = str(spec["keyword"])
        candidate = classify(rel, symbol, line_text, keyword)
        if candidate.symbol_or_line.startswith("line:") and symbol != "line:1":
            candidate.symbol_or_line = symbol
        if candidate.notes:
            candidate.notes = f"{candidate.notes}（seed）"
        else:
            candidate.notes = "seed"
        seeded.append(candidate)
    return seeded


def write_tsv(path: Path, rows: list[Candidate]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row.to_row())


def write_md(path: Path, rows: list[Candidate]) -> None:
    type_buckets: dict[str, list[Candidate]] = defaultdict(list)
    for row in rows:
        type_buckets[row.candidate_type].append(row)

    legacy_sources = {r.file_path for r in rows if r.candidate_type == "legacy_reward_source"}
    has_multi_source = len(legacy_sources) >= 2

    lines = [
        "# Battle Reward 旧流程定位报告",
        "",
        "## 扫描范围",
        "",
        "- scripts/",
        "- data/",
        "- scenes/",
        "",
        "## 总览",
        "",
        f"- 候选总数：{len(rows)}",
        f"- 旧奖励数据源候选数：{len(type_buckets['legacy_reward_source'])}",
        f"- 奖励生成函数候选数：{len(type_buckets['reward_generation_function'])}",
        f"- 战斗结算入口候选数：{len(type_buckets['battle_settlement_entry'])}",
        f"- 奖励展示入口候选数：{len(type_buckets['reward_display_entry'])}",
        f"- 奖励应用入口候选数：{len(type_buckets['reward_apply_entry'])}",
        f"- 测试/调试入口候选数：{len(type_buckets['debug_or_test_entry'])}",
        f"- 高风险触点候选数：{len(type_buckets['high_risk_touchpoint'])}",
        f"- 是否存在多个奖励来源：{'是' if has_multi_source else '否'}",
        "",
        "## 最小接入点建议",
        "",
    ]

    minimal_rows = [
        r for r in rows if "最小接入点候选" in r.notes or (r.file_path, r.symbol_or_line) == ("scripts/narrative_demo_canonical_controller.gd", "_battle_reward_for_source")
    ]
    if not minimal_rows:
        lines.append("- 暂未识别到高置信最小接入点，需人工复核。")
    else:
        for r in minimal_rows[:6]:
            lines.append(f"- `{r.file_path}`::{r.symbol_or_line}：{r.notes or r.likely_role}")

    lines.extend(["", "## 候选明细", "", "| 类型 | 文件 | 符号/行 | 关键词 | 角色判断 | 置信度 | 风险 | 建议动作 |", "|---|---|---|---|---|---|---|---|"])

    for row in rows:
        lines.append(
            "| {t} | {f} | {s} | {k} | {r} | {c} | {risk} | {a} |".format(
                t=row.candidate_type,
                f=row.file_path,
                s=row.symbol_or_line,
                k=row.matched_keyword,
                r=row.likely_role,
                c=row.confidence,
                risk=row.risk_level,
                a=row.recommended_action,
            )
        )

    lines.extend([
        "",
        "## 说明",
        "",
        "- 本报告仅基于静态文本扫描，不执行战斗逻辑。",
        "- `result/clear/gain` 这类弱关键词已做上下文过滤，仍可能存在少量噪声候选。",
        "- 正式接入应通过单一 adapter 完成，避免在多个业务脚本散落条件分支。",
        "",
    ])

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    rows = collect_candidates(max_per_file=max(1, int(args.max_per_file)))
    write_tsv(Path(args.out), rows)
    write_md(Path(args.out_md), rows)
    print(f"Wrote {args.out} and {args.out_md} with {len(rows)} candidates.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
