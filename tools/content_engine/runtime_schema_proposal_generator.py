#!/usr/bin/env python3
"""Generate Content Engine v0.7a runtime schema proposal (design-layer only)."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path

from content_package_approval_generator import APPROVAL_TSV
from content_package_manifest_generator import MANIFEST_FILENAME
from content_validator_orchestrator import SUMMARY_TSV


OUTPUT_FIELDS = [
    "schema_id",
    "runtime_domain",
    "runtime_artifact_name",
    "target_path",
    "source_artifacts",
    "required_approval_status",
    "required_validator_status",
    "requires_waiver_clearance",
    "export_allowed_now",
    "schema_status",
    "field_name",
    "field_type",
    "required",
    "default_value",
    "source_field",
    "transform_rule",
    "validation_rule",
    "notes",
]
OUTPUT_TSV = "generated_runtime_schema_proposal.tsv"
OUTPUT_MD = "generated_runtime_schema_proposal.md"

ALLOWED_RUNTIME_DOMAINS = {
    "enemy_deck",
    "card_pool",
    "battle_reward",
    "operation_node",
    "narrative_node",
    "route_gate",
    "package_manifest",
}


@dataclass(frozen=True)
class ApprovalRow:
    artifact_id: str
    validator_status: str
    approval_status: str
    approved_for_export: bool


@dataclass(frozen=True)
class SchemaField:
    field_name: str
    field_type: str
    required: bool
    default_value: str
    source_field: str
    transform_rule: str
    validation_rule: str


@dataclass(frozen=True)
class SchemaSpec:
    schema_id: str
    runtime_domain: str
    runtime_artifact_name: str
    target_path: str
    source_artifacts: tuple[str, ...]
    requires_waiver_clearance: bool
    fields: tuple[SchemaField, ...]
    notes: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Content Engine v0.7a runtime schema proposal.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default=f"data/design/{OUTPUT_TSV}")
    parser.add_argument("--out-md", default=f"data/design/{OUTPUT_MD}")
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def require_file(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Missing required input: {path}")


def parse_bool(value: str) -> bool:
    lowered = (value or "").strip().lower()
    if lowered in {"true", "1", "yes"}:
        return True
    if lowered in {"false", "0", "no"}:
        return False
    raise ValueError(f"Invalid boolean value: {value!r}")


def approval_map(rows: list[dict[str, str]]) -> dict[str, ApprovalRow]:
    mapping: dict[str, ApprovalRow] = {}
    for row in rows:
        artifact_id = (row.get("artifact_id") or "").strip()
        if not artifact_id:
            continue
        mapping[artifact_id] = ApprovalRow(
            artifact_id=artifact_id,
            validator_status=(row.get("validator_status") or "").strip(),
            approval_status=(row.get("approval_status") or "").strip(),
            approved_for_export=parse_bool((row.get("approved_for_export") or "false").strip()),
        )
    return mapping


def schema_specs() -> tuple[SchemaSpec, ...]:
    return (
        SchemaSpec(
            schema_id="schema_enemy_deck_runtime",
            runtime_domain="enemy_deck",
            runtime_artifact_name="enemy_decks.json",
            target_path="data/runtime/content_engine/enemy_decks.json",
            source_artifacts=("generated_enemy_deck_sets", "generated_card_pool", "generated_enemy_deck_skeleton"),
            requires_waiver_clearance=True,
            fields=(
                SchemaField("deck_id", "string", True, "", "deck_id", "copy", "non_empty,unique"),
                SchemaField("archetype_id", "string", True, "", "archetype_id", "copy", "non_empty"),
                SchemaField("cards", "array<object>", True, "[]", "card_id,slot_role,card_slot_index", "group_by_deck_id", "exists_in_card_pool"),
                SchemaField("ai_behavior_hint", "string", False, "", "deck_variant_role", "key_reference_only", "non_empty"),
                SchemaField("tags", "array<string>", False, "[]", "required_card_tags,forbidden_card_tags", "split_csv_tags", "non_empty"),
            ),
            notes="Long-form deck rows must be grouped by deck_id; runtime export remains blocked until WARN waiver clears.",
        ),
        SchemaSpec(
            schema_id="schema_card_pool_runtime",
            runtime_domain="card_pool",
            runtime_artifact_name="card_pool.json",
            target_path="data/runtime/content_engine/card_pool.json",
            source_artifacts=("generated_card_pool",),
            requires_waiver_clearance=False,
            fields=(
                SchemaField("card_id", "string", True, "", "card_id", "copy", "non_empty,unique"),
                SchemaField("card_class", "string", True, "", "card_class", "copy", "non_empty"),
                SchemaField("weapon_style", "string", True, "", "weapon_style", "copy", "non_empty"),
                SchemaField("tactic_role", "string", False, "", "tactic_role", "copy", "non_empty"),
                SchemaField("implementation_status", "string", True, "design_only", "implementation_status", "copy", "pass_validator_required"),
            ),
            notes="design_only card rows are not runtime-ready until explicit runtime card mapping exists.",
        ),
        SchemaSpec(
            schema_id="schema_battle_reward_runtime",
            runtime_domain="battle_reward",
            runtime_artifact_name="battle_rewards.json",
            target_path="data/runtime/content_engine/battle_rewards.json",
            source_artifacts=("generated_battle_reward_plan",),
            requires_waiver_clearance=False,
            fields=(
                SchemaField("reward_plan_id", "string", True, "", "reward_plan_id", "copy", "non_empty,unique"),
                SchemaField("battle_slot_id", "string", True, "", "battle_slot_id", "copy", "non_empty"),
                SchemaField("deck_id", "string", False, "", "deck_id", "copy", "non_empty"),
                SchemaField("martial_xp_reward", "int", True, "0", "martial_xp_reward", "parse_int", "pass_validator_required"),
                SchemaField("route_triggers", "array<string>", False, "[]", "can_trigger_true_ending,can_trigger_wuzhuangyuan", "split_csv_tags", "non_empty"),
            ),
            notes="Reward profile fields remain design-layer until runtime reward schema is implemented.",
        ),
        SchemaSpec(
            schema_id="schema_operation_node_runtime",
            runtime_domain="operation_node",
            runtime_artifact_name="operation_nodes.json",
            target_path="data/runtime/content_engine/operation_nodes.json",
            source_artifacts=("generated_operation_node_plan",),
            requires_waiver_clearance=False,
            fields=(
                SchemaField("operation_node_id", "string", True, "", "operation_node_id", "copy", "non_empty,unique"),
                SchemaField("stage", "string", True, "", "stage", "copy", "non_empty"),
                SchemaField("node_type", "string", True, "", "node_type", "copy", "non_empty"),
                SchemaField("costs", "object", False, "{}", "cost_profile", "key_reference_only", "non_empty"),
                SchemaField("route_gate_tags", "array<string>", False, "[]", "route_gate_tags", "split_csv_tags", "non_empty"),
            ),
            notes="Operation nodes require runtime mapping for cost/reward executors before export is possible.",
        ),
        SchemaSpec(
            schema_id="schema_narrative_node_runtime",
            runtime_domain="narrative_node",
            runtime_artifact_name="narrative_nodes.json",
            target_path="data/runtime/content_engine/narrative_nodes.json",
            source_artifacts=("generated_narrative_node_plan",),
            requires_waiver_clearance=False,
            fields=(
                SchemaField("narrative_node_id", "string", True, "", "narrative_node_id", "copy", "non_empty,unique"),
                SchemaField("node_kind", "string", True, "", "node_kind", "copy", "non_empty"),
                SchemaField("route_affinity", "string", False, "", "route_affinity", "copy", "non_empty"),
                SchemaField("preview_key", "string", True, "", "preview_key", "copy", "non_empty"),
                SchemaField("result_key", "string", True, "", "result_key", "copy", "non_empty"),
            ),
            notes="Narrative schema is skeleton only; no final prose body is available for runtime text delivery yet.",
        ),
        SchemaSpec(
            schema_id="schema_route_gate_runtime",
            runtime_domain="route_gate",
            runtime_artifact_name="route_gates.json",
            target_path="data/runtime/content_engine/route_gates.json",
            source_artifacts=("generated_route_gate_plan",),
            requires_waiver_clearance=False,
            fields=(
                SchemaField("route_gate_id", "string", True, "", "route_gate_id", "copy", "non_empty,unique"),
                SchemaField("route_id", "string", True, "", "route_id", "copy", "non_empty"),
                SchemaField("required_flags", "array<string>", False, "[]", "required_flags", "split_csv_tags", "non_empty"),
                SchemaField("unlock_result", "string", True, "", "unlock_result", "copy", "non_empty"),
                SchemaField("is_player_choice", "bool", False, "false", "is_player_choice", "parse_bool", "no_lightness_4_required"),
            ),
            notes="Route gate plan is design-layer only and does not equal Godot route runtime logic.",
        ),
        SchemaSpec(
            schema_id="schema_content_package_runtime_manifest",
            runtime_domain="package_manifest",
            runtime_artifact_name="content_package_manifest.json",
            target_path="data/runtime/content_engine/content_package_manifest.json",
            source_artifacts=(
                "generated_content_package_manifest",
                "generated_validator_summary",
                "generated_content_package_approval",
            ),
            requires_waiver_clearance=False,
            fields=(
                SchemaField("package_version", "string", True, "", "package_version", "copy", "non_empty"),
                SchemaField("generated_at", "string", True, "", "generated_at", "copy", "non_empty"),
                SchemaField("artifacts", "array<object>", True, "[]", "artifact_id,artifact_path", "copy", "approved_source_only"),
                SchemaField("validator_summary", "object", True, "{}", "status,warning_count,error_count", "key_reference_only", "pass_validator_required"),
                SchemaField("approval_summary", "object", True, "{}", "approval_status,approved_for_export", "key_reference_only", "approved_source_only"),
            ),
            notes="Runtime package manifest should aggregate governance tables; exporter implementation is still missing.",
        ),
    )


def export_allowed_for_schema(spec: SchemaSpec, approvals: dict[str, ApprovalRow]) -> bool:
    for artifact_id in spec.source_artifacts:
        row = approvals.get(artifact_id)
        if row is None:
            return False
        if not row.approved_for_export:
            return False
        if row.approval_status != "approved":
            return False
        if row.validator_status != "PASS":
            return False
    return True


def schema_status_for(spec: SchemaSpec, export_allowed: bool) -> str:
    if export_allowed:
        return "ready_for_review"
    if spec.requires_waiver_clearance:
        return "blocked_by_waiver"
    return "blocked_by_approval"


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def build_rows(approvals: dict[str, ApprovalRow]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for spec in schema_specs():
        export_allowed = export_allowed_for_schema(spec, approvals)
        schema_status = schema_status_for(spec, export_allowed)
        source_artifacts = ",".join(spec.source_artifacts)
        for field in spec.fields:
            rows.append(
                {
                    "schema_id": spec.schema_id,
                    "runtime_domain": spec.runtime_domain,
                    "runtime_artifact_name": spec.runtime_artifact_name,
                    "target_path": spec.target_path,
                    "source_artifacts": source_artifacts,
                    "required_approval_status": "approved",
                    "required_validator_status": "PASS",
                    "requires_waiver_clearance": "true" if spec.requires_waiver_clearance else "false",
                    "export_allowed_now": "true" if export_allowed else "false",
                    "schema_status": schema_status,
                    "field_name": field.field_name,
                    "field_type": field.field_type,
                    "required": "true" if field.required else "false",
                    "default_value": field.default_value,
                    "source_field": field.source_field,
                    "transform_rule": field.transform_rule,
                    "validation_rule": field.validation_rule,
                    "notes": spec.notes,
                }
            )
    return rows


def write_md(path: Path, rows: list[dict[str, str]], approvals: dict[str, ApprovalRow]) -> None:
    domain_rows: dict[str, dict[str, str]] = {}
    for row in rows:
        domain_rows.setdefault(row["runtime_domain"], row)
    runtime_ready_count = sum(1 for row in approvals.values() if row.approved_for_export)
    lines = [
        "# Runtime Schema Proposal",
        "",
        "- Package stage: v0.7a",
        "- Runtime export implemented: no",
        "- Export allowed now: no",
        f"- Runtime-ready artifact count: {runtime_ready_count}",
        "",
        "## Proposed Runtime Artifacts",
        "",
        "| Runtime Artifact | Domain | Target Path | Source Artifacts | Export Allowed Now |",
        "|---|---|---|---|---|",
    ]
    for domain in [
        "enemy_deck",
        "card_pool",
        "battle_reward",
        "operation_node",
        "narrative_node",
        "route_gate",
        "package_manifest",
    ]:
        row = domain_rows[domain]
        lines.append(
            f"| {row['runtime_artifact_name']} | {row['runtime_domain']} | {row['target_path']} | {row['source_artifacts']} | {row['export_allowed_now']} |"
        )

    lines.extend(
        [
            "",
            "## Export Policy",
            "",
            "- approved_for_export=true required",
            "- validator_status=PASS required",
            "- approval_status=approved required",
            "- WARN requires manual waiver",
            "- runtime exporter must not directly scan generated_*.tsv",
            "",
            "## Blockers",
            "",
            "- no approved artifacts",
            "- runtime schema not implemented in Godot",
            "- runtime exporter not implemented",
            "- two warning artifacts require waiver before export",
            "",
            "## Next Steps",
            "",
            "1. v0.7b runtime export dry-run",
            "2. only evaluate export candidates and blockers, without writing runtime files",
            "3. v0.7c runtime exporter implementation must read approval + schema proposal and only export approved artifacts",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    try:
        args = parse_args()
        design_dir = Path(args.design_dir)
        out_tsv = Path(args.out)
        out_md = Path(args.out_md)

        require_file(design_dir / MANIFEST_FILENAME)
        require_file(design_dir / SUMMARY_TSV)
        require_file(design_dir / APPROVAL_TSV)

        approvals = approval_map(read_tsv(design_dir / APPROVAL_TSV))
        rows = build_rows(approvals)
        write_tsv(out_tsv, rows)
        write_md(out_md, rows, approvals)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1

    print(f"Wrote {out_tsv} and {out_md} with {len(rows)} schema rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
