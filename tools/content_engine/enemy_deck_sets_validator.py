#!/usr/bin/env python3
"""Validate generated enemy deck sets for Content Engine v0.4b."""

from __future__ import annotations

import argparse
import csv
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path


ROLE_FIELDS = {
    "attack": "attack_card_count",
    "guard": "guard_card_count",
    "movement": "movement_card_count",
    "posture_break": "posture_break_card_count",
    "tempo": "tempo_card_count",
    "combo": "combo_card_count",
    "special": "special_card_count",
}
ROLE_ORDER = ["attack", "guard", "movement", "posture_break", "tempo", "combo", "special"]


@dataclass
class ValidationReport:
    passes: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    failures: list[str] = field(default_factory=list)

    def pass_(self, message: str) -> None:
        self.passes.append(message)

    def warn(self, message: str) -> None:
        self.warnings.append(message)

    def fail(self, message: str) -> None:
        self.failures.append(message)

    def ok(self) -> bool:
        return not self.failures

    def format(self) -> str:
        lines: list[str] = []
        lines.extend([f"PASS: {item}" for item in self.passes])
        lines.extend([f"WARN: {item}" for item in self.warnings])
        lines.extend([f"FAIL: {item}" for item in self.failures])
        lines.append("RESULT: PASS" if self.ok() else "RESULT: FAIL")
        return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.4b enemy deck sets.")
    parser.add_argument("--design-dir", default="data/design")
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def as_int(value: str, default: int = 0) -> int:
    try:
        return int(round(float((value or "").strip())))
    except ValueError:
        return default


def tags(value: str) -> set[str]:
    return {part.strip() for part in value.split(",") if part.strip()}


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    sets_path = design_dir / "generated_enemy_deck_sets.tsv"
    skeleton_path = design_dir / "generated_enemy_deck_skeleton.tsv"
    pool_path = design_dir / "generated_card_pool.tsv"
    for path in [sets_path, skeleton_path, pool_path]:
        if not path.exists():
            report.fail(f"Missing required file: {path}")
            return report
    report.pass_(f"Found {sets_path}")
    report.pass_(f"Found {skeleton_path}")
    report.pass_(f"Found {pool_path}")

    set_rows = read_tsv(sets_path)
    skeleton_rows = read_tsv(skeleton_path)
    pool_rows = read_tsv(pool_path)
    if not set_rows:
        report.fail("generated_enemy_deck_sets.tsv is empty.")
        return report

    skeleton_by_id = {row.get("deck_skeleton_id", ""): row for row in skeleton_rows}
    pool_by_id = {row.get("card_id", ""): row for row in pool_rows}
    deck_rows = group_by(set_rows, "deck_id")

    validate_references(deck_rows, skeleton_by_id, pool_by_id, report)
    validate_counts(deck_rows, skeleton_by_id, report)
    validate_role_alignment(deck_rows, skeleton_by_id, report)
    validate_tag_constraints(deck_rows, report)
    validate_repeat_limits(deck_rows, report)
    validate_structure_constraints(deck_rows, skeleton_by_id, report)
    validate_scope_totals(deck_rows, report)
    return report


def group_by(rows: list[dict[str, str]], key: str) -> dict[str, list[dict[str, str]]]:
    grouped: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[row.get(key, "")].append(row)
    return dict(grouped)


def validate_references(
    deck_rows: dict[str, list[dict[str, str]]],
    skeleton_by_id: dict[str, dict[str, str]],
    pool_by_id: dict[str, dict[str, str]],
    report: ValidationReport,
) -> None:
    bad_skeleton: list[str] = []
    bad_card: list[str] = []
    for deck_id, rows in deck_rows.items():
        skeleton_id = rows[0].get("deck_skeleton_id", "")
        if skeleton_id not in skeleton_by_id:
            bad_skeleton.append(deck_id)
        for row in rows:
            card_id = row.get("card_id", "")
            if card_id not in pool_by_id:
                bad_card.append(f"{deck_id}:{card_id}")
    if bad_skeleton:
        report.fail("Unknown deck_skeleton_id in deck sets: " + ", ".join(bad_skeleton))
    else:
        report.pass_("Every deck_id maps to an existing deck_skeleton_id.")
    if bad_card:
        report.fail("Unknown card_id in deck sets: " + ", ".join(bad_card))
    else:
        report.pass_("Every card_id exists in generated_card_pool.tsv.")


def validate_counts(
    deck_rows: dict[str, list[dict[str, str]]],
    skeleton_by_id: dict[str, dict[str, str]],
    report: ValidationReport,
) -> None:
    mismatched: list[str] = []
    for deck_id, rows in deck_rows.items():
        skeleton = skeleton_by_id.get(rows[0].get("deck_skeleton_id", ""), {})
        target = as_int(skeleton.get("target_card_count", ""), -1)
        if len(rows) != target:
            mismatched.append(f"{deck_id} expected={target} actual={len(rows)}")
    if mismatched:
        report.fail("Deck size mismatch to target_card_count: " + ", ".join(mismatched))
    else:
        report.pass_("Every deck size matches skeleton target_card_count.")


def validate_role_alignment(
    deck_rows: dict[str, list[dict[str, str]]],
    skeleton_by_id: dict[str, dict[str, str]],
    report: ValidationReport,
) -> None:
    bad_card_role: list[str] = []
    bad_distribution: list[str] = []
    for deck_id, rows in deck_rows.items():
        for row in rows:
            if row.get("card_deck_role", "") != row.get("slot_role", ""):
                bad_card_role.append(f"{deck_id}:{row.get('card_slot_index', '')}:{row.get('card_id', '')}")

        skeleton = skeleton_by_id.get(rows[0].get("deck_skeleton_id", ""), {})
        expected_roles = normalized_role_counts(skeleton)
        actual = Counter(row.get("slot_role", "") for row in rows)
        for role in ROLE_ORDER:
            if actual.get(role, 0) != expected_roles.get(role, 0):
                bad_distribution.append(f"{deck_id}:{role} expected={expected_roles.get(role,0)} actual={actual.get(role,0)}")

    if bad_card_role:
        report.fail("card_deck_role must match slot_role: " + ", ".join(bad_card_role))
    else:
        report.pass_("card_deck_role equals slot_role for all rows.")
    if bad_distribution:
        report.fail("slot_role distribution mismatch to normalized skeleton counts: " + ", ".join(bad_distribution))
    else:
        report.pass_("Every deck slot_role distribution matches normalized skeleton counts.")


def normalized_role_counts(skeleton: dict[str, str]) -> dict[str, int]:
    counts = {role: as_int(skeleton.get(field, ""), 0) for role, field in ROLE_FIELDS.items()}
    target = as_int(skeleton.get("target_card_count", ""), 0)
    current = sum(counts.values())
    scope = skeleton.get("scope", "")

    if current < target:
        for role in add_priority(scope):
            if current >= target:
                break
            counts[role] += 1
            current += 1
    if current > target:
        for role in trim_priority(scope):
            while current > target and counts[role] > 0:
                counts[role] -= 1
                current -= 1
            if current <= target:
                break
    return counts


def add_priority(scope: str) -> list[str]:
    if scope == "wuzhuangyuan_exam":
        return ["guard", "movement", "posture_break", "attack", "tempo", "combo", "special"] * 8
    if scope in {"boss_normal", "boss_true"}:
        return ["attack", "guard", "movement", "tempo", "special", "posture_break", "combo"] * 8
    return ["attack", "guard", "movement", "posture_break", "tempo", "combo", "special"] * 8


def trim_priority(scope: str) -> list[str]:
    if scope == "wuzhuangyuan_exam":
        return ["special", "combo", "tempo", "attack", "movement", "guard", "posture_break"]
    if scope in {"boss_normal", "boss_true"}:
        return ["combo", "movement", "guard", "attack", "posture_break", "tempo", "special"]
    return ["special", "combo", "tempo", "movement", "guard", "attack", "posture_break"]


def validate_tag_constraints(deck_rows: dict[str, list[dict[str, str]]], report: ValidationReport) -> None:
    forbidden_hits: list[str] = []
    required_miss: list[str] = []
    normal_boss_tag: list[str] = []
    generic_boss_tag: list[str] = []
    required_lightness: list[str] = []
    boss_exam_required_lightness: list[str] = []

    for deck_id, rows in deck_rows.items():
        scope = rows[0].get("scope", "")
        required = tags(rows[0].get("required_card_tags", ""))
        has_required_match = not required
        if "lightness_4_required" in required:
            required_lightness.append(deck_id)
        if scope in {"boss_normal", "boss_true", "wuzhuangyuan_exam"} and "lightness_4_required" in required:
            boss_exam_required_lightness.append(deck_id)

        for row in rows:
            card_tags = tags(row.get("card_tags", ""))
            forbidden = tags(row.get("forbidden_card_tags", ""))
            card_style = row.get("card_weapon_style", "")
            if card_tags & forbidden:
                forbidden_hits.append(f"{deck_id}:{row.get('card_id', '')}")
            if required_reasonable_match(required, card_tags, card_style):
                has_required_match = True

            has_boss_flag = "boss_only" in card_tags or "true_boss_only" in card_tags or card_style == "boss"
            if scope not in {"boss_normal", "boss_true"} and has_boss_flag:
                normal_boss_tag.append(f"{deck_id}:{row.get('card_id', '')}")
            if card_style == "generic" and ("boss_only" in card_tags or "true_boss_only" in card_tags):
                generic_boss_tag.append(f"{deck_id}:{row.get('card_id', '')}")

        if not has_required_match:
            required_miss.append(deck_id)

    if forbidden_hits:
        report.fail("forbidden_card_tags intersects card_tags: " + ", ".join(forbidden_hits))
    else:
        report.pass_("No forbidden_card_tags/card_tags intersections.")
    if required_miss:
        report.warn("required_card_tags weak match on some decks: " + ", ".join(required_miss))
    else:
        report.pass_("required_card_tags has reasonable match to selected cards.")
    if normal_boss_tag:
        report.fail("non-boss deck using boss-only style/tags: " + ", ".join(normal_boss_tag))
    else:
        report.pass_("normal/elite/exam decks do not use boss-only style cards.")
    if generic_boss_tag:
        report.fail("generic card incorrectly tagged boss-only: " + ", ".join(generic_boss_tag))
    else:
        report.pass_("generic cards are not marked boss-only.")
    if required_lightness:
        report.fail("required_card_tags must not include lightness_4_required: " + ", ".join(required_lightness))
    else:
        report.pass_("No deck requires lightness_4_required.")
    if boss_exam_required_lightness:
        report.fail("Boss/exam decks must not require lightness_4_required: " + ", ".join(boss_exam_required_lightness))
    else:
        report.pass_("Boss/exam decks do not require lightness_4_required.")


def required_reasonable_match(required: set[str], card_tags: set[str], card_style: str) -> bool:
    if not required:
        return True
    if required & card_tags:
        return True
    if "weapon_spearman" in required and card_style in {"spearman", "generic"}:
        return True
    if "weapon_blademaster" in required and card_style in {"blademaster", "generic"}:
        return True
    if "weapon_firearm" in required and card_style in {"firearm", "generic"}:
        return True
    if "exam_official" in required and card_style in {"official", "generic", "mixed"}:
        return True
    if "role_fundamental" in required and card_style in {"official", "generic", "mixed"}:
        return True
    if any(tag.startswith("generic_") for tag in required) and card_style == "generic":
        return True
    if any(tag.startswith("boss_") for tag in required) and card_style == "boss":
        return True
    if any(tag.startswith("footwork_") for tag in required) and card_style in {"generic", "official", "mixed"}:
        return True
    return False


def validate_repeat_limits(deck_rows: dict[str, list[dict[str, str]]], report: ValidationReport) -> None:
    bad: list[str] = []
    for deck_id, rows in deck_rows.items():
        scope = rows[0].get("scope", "")
        max_repeat = 3 if scope in {"boss_normal", "boss_true"} else 2
        counts = Counter(row.get("card_id", "") for row in rows)
        for card_id, value in counts.items():
            if value > max_repeat:
                bad.append(f"{deck_id}:{card_id}={value}>{max_repeat}")
    if bad:
        report.fail("repeat limits exceeded: " + ", ".join(bad))
    else:
        report.pass_("Per-deck duplicate card limits are respected.")


def validate_structure_constraints(
    deck_rows: dict[str, list[dict[str, str]]],
    skeleton_by_id: dict[str, dict[str, str]],
    report: ValidationReport,
) -> None:
    bad_guard_move: list[str] = []
    bad_attack_break: list[str] = []
    bad_boss_coverage: list[str] = []
    bad_exam_coverage: list[str] = []
    bad_firearm: list[str] = []

    for deck_id, rows in deck_rows.items():
        scope = rows[0].get("scope", "")
        role_counter = Counter(row.get("slot_role", "") for row in rows)
        if role_counter.get("guard", 0) + role_counter.get("movement", 0) < 1:
            bad_guard_move.append(deck_id)
        if role_counter.get("attack", 0) + role_counter.get("posture_break", 0) < 1:
            bad_attack_break.append(deck_id)

        if scope in {"boss_normal", "boss_true"}:
            covered = sum(1 for role in ["attack", "guard", "posture_break", "tempo"] if role_counter.get(role, 0) > 0)
            if covered < 3:
                bad_boss_coverage.append(deck_id)
        if scope == "wuzhuangyuan_exam":
            covered = sum(1 for role in ["attack", "guard", "movement", "posture_break"] if role_counter.get(role, 0) > 0)
            if covered < 3:
                bad_exam_coverage.append(deck_id)

        skeleton = skeleton_by_id.get(rows[0].get("deck_skeleton_id", ""), {})
        if skeleton.get("weapon_style") == "firearm":
            all_attack = all(row.get("slot_role", "") == "attack" for row in rows)
            pref_min = as_int(rows[0].get("preferred_distance_min", ""), 0)
            pref_max = as_int(rows[0].get("preferred_distance_max", ""), 0)
            if all_attack and pref_min >= 3 and pref_max >= 4:
                bad_firearm.append(deck_id)

    if bad_guard_move:
        report.fail("Deck missing guard/movement baseline: " + ", ".join(bad_guard_move))
    else:
        report.pass_("Every deck has guard or movement.")
    if bad_attack_break:
        report.fail("Deck missing attack/posture_break baseline: " + ", ".join(bad_attack_break))
    else:
        report.pass_("Every deck has attack or posture_break.")
    if bad_boss_coverage:
        report.fail("Boss deck role coverage too narrow: " + ", ".join(bad_boss_coverage))
    else:
        report.pass_("Boss deck coverage constraint satisfied.")
    if bad_exam_coverage:
        report.fail("Wuzhuangyuan deck role coverage too narrow: " + ", ".join(bad_exam_coverage))
    else:
        report.pass_("Wuzhuangyuan deck coverage constraint satisfied.")
    if bad_firearm:
        report.fail("Firearm deck locked to all-attack long range: " + ", ".join(bad_firearm))
    else:
        report.pass_("Firearm decks include counterplay structure.")


def validate_scope_totals(deck_rows: dict[str, list[dict[str, str]]], report: ValidationReport) -> None:
    scope_counter = Counter(rows[0].get("scope", "") for rows in deck_rows.values())
    normal = scope_counter.get("big_map_normal", 0)
    elite = scope_counter.get("big_map_elite", 0)
    boss = scope_counter.get("boss_normal", 0) + scope_counter.get("boss_true", 0)
    exam = scope_counter.get("wuzhuangyuan_exam", 0)

    if 20 <= normal <= 24:
        report.pass_(f"Normal deck count is {normal} (expected around 22, range 20-24).")
    else:
        report.fail(f"Normal deck count out of expected range: {normal}.")
    if elite == 8:
        report.pass_("Elite deck count is 8.")
    else:
        report.fail(f"Elite deck count expected 8, got {elite}.")
    if boss == 4:
        report.pass_("Boss deck count is 4.")
    else:
        report.fail(f"Boss deck count expected 4, got {boss}.")
    if exam == 5:
        report.pass_("Wuzhuangyuan deck count is 5.")
    else:
        report.fail(f"Wuzhuangyuan deck count expected 5, got {exam}.")


def main() -> int:
    args = parse_args()
    report = validate(Path(args.design_dir))
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
