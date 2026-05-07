#!/usr/bin/env python3
"""Load progression numeric config TSV files for Content Engine tools."""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


REQUIRED_FIELDS = [
    "config_id",
    "category",
    "scope",
    "route",
    "stage",
    "metric",
    "min_value",
    "default_value",
    "max_value",
    "unit",
    "value_type",
    "enum_value",
    "is_tunable",
    "source_section",
    "notes",
]


@dataclass(frozen=True)
class ConfigRow:
    values: dict[str, str]

    def get(self, field: str, default: str = "") -> str:
        return self.values.get(field, default).strip()

    def number(self, field: str = "default_value", default: float = 0.0) -> float:
        text = self.get(field)
        if text == "":
            return default
        try:
            return float(text)
        except ValueError:
            return default

    def integer(self, field: str = "default_value", default: int = 0) -> int:
        return int(round(self.number(field, float(default))))


class ProgressionConfig:
    def __init__(self, rows: Iterable[ConfigRow]) -> None:
        self.rows = list(rows)
        self.by_config_id = {row.get("config_id"): row for row in self.rows}

    def get(self, config_id: str) -> ConfigRow | None:
        return self.by_config_id.get(config_id)

    def number(self, config_id: str, field: str = "default_value", default: float = 0.0) -> float:
        row = self.get(config_id)
        if row is None:
            return default
        return row.number(field, default)

    def integer(self, config_id: str, field: str = "default_value", default: int = 0) -> int:
        row = self.get(config_id)
        if row is None:
            return default
        return row.integer(field, default)

    def query(
        self,
        *,
        config_id: str | None = None,
        category: str | None = None,
        scope: str | None = None,
        route: str | None = None,
        stage: str | None = None,
        metric: str | None = None,
    ) -> list[ConfigRow]:
        filters = {
            "config_id": config_id,
            "category": category,
            "scope": scope,
            "route": route,
            "stage": stage,
            "metric": metric,
        }
        result: list[ConfigRow] = []
        for row in self.rows:
            if all(value is None or row.get(field) == value for field, value in filters.items()):
                result.append(row)
        return result


def load_config(path: str | Path) -> ProgressionConfig:
    config_path = Path(path)
    if not config_path.exists():
        raise FileNotFoundError(f"Progression config not found: {config_path}")

    with config_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if reader.fieldnames is None:
            raise ValueError(f"Progression config is empty: {config_path}")
        missing = [field for field in REQUIRED_FIELDS if field not in reader.fieldnames]
        if missing:
            raise ValueError(
                "Progression config missing required fields: "
                + ", ".join(missing)
                + f" in {config_path}"
            )
        rows = [ConfigRow({field: (raw.get(field) or "") for field in REQUIRED_FIELDS}) for raw in reader]

    if not rows:
        raise ValueError(f"Progression config has no data rows: {config_path}")
    return ProgressionConfig(rows)


def write_minimal_sample_config(path: str | Path) -> None:
    """Write a small runnable sample when the preferred design config is absent."""
    config_path = Path(path)
    config_path.parent.mkdir(parents=True, exist_ok=True)
    rows = [
        _sample("flow_prologue_battles", "flow_count", "global", "all", "prologue", "序章战斗数", 1, 1, 1, "battle", "int"),
        _sample("flow_wuju_total_battles", "flow_count", "global", "all", "wuju", "武举线总战斗数", 5, 5, 5, "battle", "int"),
        _sample("flow_big_map_battles", "flow_count", "global", "all", "big_map", "大地图实际战斗数", 14, 15, 16, "battle", "int"),
        _sample("big_map_pool_multiplier", "enemy_pool", "big_map", "all", "big_map", "大地图候选池倍率", 2, 2, 2, "multiplier", "float"),
        _sample("reward_prologue_martial_xp", "martial_reward", "global", "all", "prologue", "序章 martial_xp 奖励", 3, 3, 3, "martial_xp", "int"),
        _sample("reward_big_map_normal_martial_xp", "martial_reward", "big_map", "all", "normal_battle", "普通战 martial_xp", 5, 5, 5, "martial_xp", "int"),
        _sample("reward_big_map_elite_martial_xp", "martial_reward", "big_map", "all", "elite_battle", "精英战 martial_xp", 12, 12, 12, "martial_xp", "int"),
    ]
    with config_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=REQUIRED_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _sample(
    config_id: str,
    category: str,
    scope: str,
    route: str,
    stage: str,
    metric: str,
    min_value: int | float,
    default_value: int | float,
    max_value: int | float,
    unit: str,
    value_type: str,
) -> dict[str, str]:
    return {
        "config_id": config_id,
        "category": category,
        "scope": scope,
        "route": route,
        "stage": stage,
        "metric": metric,
        "min_value": str(min_value),
        "default_value": str(default_value),
        "max_value": str(max_value),
        "unit": unit,
        "value_type": value_type,
        "enum_value": "",
        "is_tunable": "TRUE",
        "source_section": "minimal_sample",
        "notes": "Minimal runnable sample generated by Content Engine v0.1.",
    }
