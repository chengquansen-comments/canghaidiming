#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MVP_PATH = ROOT / "data" / "aigc_battle" / "story" / "story_beat_mvp_pool.json"
OUTPUT_PATH = ROOT / "data" / "aigc_battle" / "story" / "story_beat_expanded_pool.json"
TARGET_COUNTS = {
    "military": 72,
    "reputation": 72,
    "old_case": 72,
    "cross": 84,
}

PREVIEW_FRAMES = [
    "同一条海防线上，又有新的回声：{text}",
    "换到另一处潮口，这件事显出不同侧面：{text}",
    "军民交界处，旧事换了说法：{text}",
    "海风压低时，局面重新摆到你面前：{text}",
    "沿着汛路再查一步，线索变得更窄：{text}",
]
RESULT_FRAMES = [
    "{text} 这一次，留下的是更难回避的后果。",
    "{text} 你把它记入海防账，也记入人情账。",
    "{text} 这条线没有断，只是转向更深处。",
    "{text} 旁人看见的是结果，你看见的是下一重代价。",
    "{text} 海疆暂稳，心里的秤却更沉。",
]
ROUTE_DETAILS = {
    "military": ["军令", "哨船", "封港", "粮道", "营门"],
    "reputation": ["祠前", "鱼市", "渡口", "民册", "暗灯"],
    "old_case": ["旧卷", "潮痕", "火漆", "税账", "船号"],
    "cross": ["军令与民证", "旧名与血证", "功劳与真相", "潮图与供词", "官面与人心"],
}


def main() -> int:
    base_beats = json.loads(MVP_PATH.read_text(encoding="utf-8"))
    if not isinstance(base_beats, list) or not base_beats:
        raise SystemExit(f"missing MVP beat pool: {MVP_PATH}")
    expanded = [dict(item) for item in base_beats]
    counts = Counter(str(item["route_line"]) for item in expanded)
    by_route: dict[str, list[dict[str, Any]]] = {route: [] for route in TARGET_COUNTS}
    for item in base_beats:
        route = str(item["route_line"])
        if route in by_route:
            by_route[route].append(item)
    for route, target in TARGET_COUNTS.items():
        route_beats = by_route[route]
        if not route_beats:
            raise SystemExit(f"no base beats for route: {route}")
        cursor = 0
        variant_index = 2
        while counts[route] < target:
            base = route_beats[cursor % len(route_beats)]
            expanded.append(_variant(base, variant_index))
            counts[route] += 1
            cursor += 1
            if cursor % len(route_beats) == 0:
                variant_index += 1
    if len(expanded) != 300:
        raise SystemExit(f"expected 300 expanded beats, got {len(expanded)}")
    _assert_unique_ids(expanded)
    OUTPUT_PATH.write_text(json.dumps(expanded, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(expanded)} beats to {OUTPUT_PATH.relative_to(ROOT)}")
    print("Route counts:", dict(Counter(str(item["route_line"]) for item in expanded)))
    return 0


def _variant(base: dict[str, Any], variant_index: int) -> dict[str, Any]:
    beat = json.loads(json.dumps(base, ensure_ascii=False))
    base_id = str(base["story_beat_id"])
    route = str(base["route_line"])
    phase = str(base["phase"])
    detail = ROUTE_DETAILS[route][(variant_index + len(base_id)) % len(ROUTE_DETAILS[route])]
    preview_frame = PREVIEW_FRAMES[(variant_index + len(phase)) % len(PREVIEW_FRAMES)]
    result_frame = RESULT_FRAMES[(variant_index + len(route)) % len(RESULT_FRAMES)]
    beat["story_beat_id"] = f"{base_id}_alt_{variant_index:02d}"
    beat["preview_text"] = f"{preview_frame.format(text=str(base['preview_text']))}【{detail}】"
    beat["result_text"] = f"{result_frame.format(text=str(base['result_text']))}【{phase}/{detail}】"
    beat["weight"] = max(1, int(base.get("weight", 1)) - variant_index)
    return beat


def _assert_unique_ids(beats: list[dict[str, Any]]) -> None:
    seen: set[str] = set()
    for item in beats:
        beat_id = str(item["story_beat_id"])
        if beat_id in seen:
            raise SystemExit(f"duplicate story_beat_id: {beat_id}")
        seen.add(beat_id)


if __name__ == "__main__":
    raise SystemExit(main())
