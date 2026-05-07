#!/usr/bin/env python3
"""Generate Content Engine v0.6a content package manifest (design-layer only)."""

from __future__ import annotations

import argparse
import csv
import hashlib
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


MANIFEST_ID = "content_package_manifest_v0_6a"
PACKAGE_VERSION = "v0.6a"
MANIFEST_FILENAME = "generated_content_package_manifest.tsv"
MANIFEST_FIELDS = [
    "manifest_id",
    "package_version",
    "artifact_id",
    "artifact_type",
    "artifact_path",
    "source_stage",
    "generator_script",
    "validator_script",
    "required_inputs",
    "depends_on_artifacts",
    "row_count",
    "checksum_sha256",
    "validator_status",
    "validator_warning_count",
    "validator_error_count",
    "is_runtime_ready",
    "export_scope",
    "export_blockers",
    "notes",
]


@dataclass(frozen=True)
class ArtifactSpec:
    artifact_id: str
    filename: str
    artifact_type: str
    source_stage: str
    generator_script: str
    validator_script: str
    required_inputs: tuple[str, ...]
    depends_on_artifacts: tuple[str, ...]
    export_scope: str
    export_blockers: tuple[str, ...]
    notes: str = ""
    is_runtime_ready: bool = False
    default_validator_status: str = "NOT_RUN"


ARTIFACT_SPECS = [
    ArtifactSpec(
        artifact_id="progression_numeric_config_v1_3",
        filename="progression_numeric_config_v1_3.tsv",
        artifact_type="source_config",
        source_stage="v0.1",
        generator_script="manual_source",
        validator_script="tools/content_engine/progression_validator.py",
        required_inputs=(),
        depends_on_artifacts=(),
        export_scope="none",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined"),
        notes="Manual numeric source config for design-layer progression planning.",
        default_validator_status="SOURCE_ONLY",
    ),
    ArtifactSpec(
        artifact_id="generated_battle_slot_plan",
        filename="generated_battle_slot_plan.tsv",
        artifact_type="design_plan",
        source_stage="v0.1",
        generator_script="tools/content_engine/progression_plan_builder.py",
        validator_script="tools/content_engine/progression_validator.py",
        required_inputs=("data/design/progression_numeric_config_v1_3.tsv",),
        depends_on_artifacts=("progression_numeric_config_v1_3",),
        export_scope="future_runtime",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined", "needs_manual_review"),
        notes="Design-layer battle slot structure; manifest generation does not rerun validators by default.",
    ),
    ArtifactSpec(
        artifact_id="generated_enemy_deck_requirement",
        filename="generated_enemy_deck_requirement.tsv",
        artifact_type="design_plan",
        source_stage="v0.1",
        generator_script="tools/content_engine/progression_plan_builder.py",
        validator_script="tools/content_engine/progression_validator.py",
        required_inputs=("data/design/progression_numeric_config_v1_3.tsv",),
        depends_on_artifacts=("progression_numeric_config_v1_3",),
        export_scope="future_runtime",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined", "needs_manual_review"),
        notes="Design-layer deck requirement structure; manifest generation does not rerun validators by default.",
    ),
    ArtifactSpec(
        artifact_id="generated_route_progression_curve",
        filename="generated_route_progression_curve.tsv",
        artifact_type="design_plan",
        source_stage="v0.1",
        generator_script="tools/content_engine/progression_plan_builder.py",
        validator_script="tools/content_engine/progression_validator.py",
        required_inputs=("data/design/progression_numeric_config_v1_3.tsv",),
        depends_on_artifacts=("progression_numeric_config_v1_3",),
        export_scope="future_runtime",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined", "needs_manual_review"),
        notes="Design-layer route curve structure; manifest generation does not rerun validators by default.",
    ),
    ArtifactSpec(
        artifact_id="generated_operation_node_requirement",
        filename="generated_operation_node_requirement.tsv",
        artifact_type="design_plan",
        source_stage="v0.1.1",
        generator_script="tools/content_engine/progression_plan_builder.py",
        validator_script="tools/content_engine/progression_validator.py",
        required_inputs=("data/design/progression_numeric_config_v1_3.tsv",),
        depends_on_artifacts=("progression_numeric_config_v1_3",),
        export_scope="future_runtime",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined", "needs_manual_review"),
        notes="Design-layer operation-node requirement structure; manifest generation does not rerun validators by default.",
    ),
    ArtifactSpec(
        artifact_id="generated_enemy_archetype_pool",
        filename="generated_enemy_archetype_pool.tsv",
        artifact_type="generated_table",
        source_stage="v0.2",
        generator_script="tools/content_engine/enemy_archetype_generator.py",
        validator_script="tools/content_engine/enemy_archetype_validator.py",
        required_inputs=(
            "data/design/generated_enemy_deck_requirement.tsv",
            "data/design/generated_battle_slot_plan.tsv",
            "data/design/generated_route_progression_curve.tsv",
            "data/design/generated_operation_node_requirement.tsv",
        ),
        depends_on_artifacts=(
            "generated_enemy_deck_requirement",
            "generated_battle_slot_plan",
            "generated_route_progression_curve",
            "generated_operation_node_requirement",
        ),
        export_scope="future_runtime",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined", "needs_manual_review"),
        notes="Design-layer enemy archetype pool for downstream deck skeleton planning.",
    ),
    ArtifactSpec(
        artifact_id="generated_enemy_deck_skeleton",
        filename="generated_enemy_deck_skeleton.tsv",
        artifact_type="generated_table",
        source_stage="v0.3",
        generator_script="tools/content_engine/enemy_deck_skeleton_generator.py",
        validator_script="tools/content_engine/enemy_deck_skeleton_validator.py",
        required_inputs=(
            "data/design/generated_enemy_archetype_pool.tsv",
            "data/design/generated_enemy_deck_requirement.tsv",
            "data/design/generated_battle_slot_plan.tsv",
        ),
        depends_on_artifacts=(
            "generated_enemy_archetype_pool",
            "generated_enemy_deck_requirement",
            "generated_battle_slot_plan",
        ),
        export_scope="future_runtime",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined", "needs_manual_review"),
        notes="Design-layer deck skeleton constraints; still not runtime deck data.",
    ),
    ArtifactSpec(
        artifact_id="generated_card_pool",
        filename="generated_card_pool.tsv",
        artifact_type="generated_table",
        source_stage="v0.4a",
        generator_script="tools/content_engine/card_pool_generator.py",
        validator_script="tools/content_engine/card_pool_validator.py",
        required_inputs=(
            "data/design/generated_enemy_deck_skeleton.tsv",
            "data/design/generated_enemy_archetype_pool.tsv",
            "data/design/generated_enemy_deck_requirement.tsv",
        ),
        depends_on_artifacts=(
            "generated_enemy_deck_skeleton",
            "generated_enemy_archetype_pool",
            "generated_enemy_deck_requirement",
        ),
        export_scope="future_runtime",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined", "needs_manual_review"),
        notes="Design-layer card pool only; runtime card data is out of scope for v0.6a.",
    ),
    ArtifactSpec(
        artifact_id="generated_enemy_deck_sets",
        filename="generated_enemy_deck_sets.tsv",
        artifact_type="generated_table",
        source_stage="v0.4b",
        generator_script="tools/content_engine/enemy_deck_sets_generator.py",
        validator_script="tools/content_engine/enemy_deck_sets_validator.py",
        required_inputs=(
            "data/design/generated_enemy_deck_skeleton.tsv",
            "data/design/generated_card_pool.tsv",
            "data/design/generated_enemy_archetype_pool.tsv",
            "data/design/generated_enemy_deck_requirement.tsv",
        ),
        depends_on_artifacts=(
            "generated_enemy_deck_skeleton",
            "generated_card_pool",
            "generated_enemy_archetype_pool",
            "generated_enemy_deck_requirement",
        ),
        export_scope="future_runtime",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined", "needs_manual_review"),
        notes="Design-layer enemy deck set instances; runtime exporter is intentionally absent in v0.6a.",
    ),
    ArtifactSpec(
        artifact_id="generated_battle_reward_plan",
        filename="generated_battle_reward_plan.tsv",
        artifact_type="reward_plan",
        source_stage="v0.5a",
        generator_script="tools/content_engine/battle_reward_generator.py",
        validator_script="tools/content_engine/battle_reward_validator.py",
        required_inputs=(
            "data/design/generated_battle_slot_plan.tsv",
            "data/design/generated_enemy_deck_skeleton.tsv",
            "data/design/generated_enemy_deck_sets.tsv",
            "data/design/generated_enemy_archetype_pool.tsv",
            "data/design/generated_route_progression_curve.tsv",
            "data/design/progression_numeric_config_v1_3.tsv",
        ),
        depends_on_artifacts=(
            "generated_battle_slot_plan",
            "generated_enemy_deck_skeleton",
            "generated_enemy_deck_sets",
            "generated_enemy_archetype_pool",
            "generated_route_progression_curve",
            "progression_numeric_config_v1_3",
        ),
        export_scope="future_runtime",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined", "needs_manual_review"),
        notes="Design-layer battle reward plan with route and reward traces for later export/reporting.",
    ),
    ArtifactSpec(
        artifact_id="generated_operation_node_plan",
        filename="generated_operation_node_plan.tsv",
        artifact_type="generated_table",
        source_stage="v0.5b",
        generator_script="tools/content_engine/operation_node_generator.py",
        validator_script="tools/content_engine/operation_node_validator.py",
        required_inputs=(
            "data/design/generated_operation_node_requirement.tsv",
            "data/design/generated_battle_reward_plan.tsv",
            "data/design/generated_route_progression_curve.tsv",
            "data/design/progression_numeric_config_v1_3.tsv",
        ),
        depends_on_artifacts=(
            "generated_operation_node_requirement",
            "generated_battle_reward_plan",
            "generated_route_progression_curve",
            "progression_numeric_config_v1_3",
        ),
        export_scope="future_runtime",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined", "needs_manual_review"),
        notes="Design-layer operation node instances and route tags only.",
    ),
    ArtifactSpec(
        artifact_id="generated_narrative_node_plan",
        filename="generated_narrative_node_plan.tsv",
        artifact_type="narrative_plan",
        source_stage="v0.5c",
        generator_script="tools/content_engine/narrative_node_generator.py",
        validator_script="tools/content_engine/narrative_node_validator.py",
        required_inputs=(
            "data/design/generated_operation_node_plan.tsv",
            "data/design/generated_battle_reward_plan.tsv",
            "data/design/generated_route_progression_curve.tsv",
            "data/design/generated_battle_slot_plan.tsv",
        ),
        depends_on_artifacts=(
            "generated_operation_node_plan",
            "generated_battle_reward_plan",
            "generated_route_progression_curve",
            "generated_battle_slot_plan",
        ),
        export_scope="future_runtime",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined", "needs_manual_review"),
        notes="Narrative skeleton plan only; no prose body generation and no runtime narrative export.",
    ),
    ArtifactSpec(
        artifact_id="generated_route_gate_plan",
        filename="generated_route_gate_plan.tsv",
        artifact_type="route_gate_plan",
        source_stage="v0.5d",
        generator_script="tools/content_engine/route_gate_generator.py",
        validator_script="tools/content_engine/route_gate_validator.py",
        required_inputs=(
            "data/design/generated_battle_reward_plan.tsv",
            "data/design/generated_operation_node_plan.tsv",
            "data/design/generated_narrative_node_plan.tsv",
            "data/design/generated_route_progression_curve.tsv",
            "data/design/progression_numeric_config_v1_3.tsv",
        ),
        depends_on_artifacts=(
            "generated_battle_reward_plan",
            "generated_operation_node_plan",
            "generated_narrative_node_plan",
            "generated_route_progression_curve",
            "progression_numeric_config_v1_3",
        ),
        export_scope="future_runtime",
        export_blockers=("runtime_exporter_not_implemented", "runtime_schema_not_defined", "needs_manual_review"),
        notes="Design-layer route gate aggregation only; runtime route gate export remains blocked.",
    ),
]

CORE_ARTIFACT_IDS = {spec.artifact_id for spec in ARTIFACT_SPECS}


@dataclass(frozen=True)
class ValidatorResult:
    status: str
    warning_count: int
    error_count: int
    stdout: str
    returncode: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Content Engine v0.6a content package manifest.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default=f"data/design/{MANIFEST_FILENAME}")
    parser.add_argument(
        "--run-validators",
        action="store_true",
        help="Run referenced validators before writing manifest and record PASS/WARN/FAIL counts.",
    )
    return parser.parse_args()


def read_tsv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def count_rows(path: Path) -> int:
    return len(read_tsv_rows(path))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=MANIFEST_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def display_path(path: Path) -> str:
    try:
        return path.relative_to(Path.cwd()).as_posix()
    except ValueError:
        return path.as_posix()


def run_validator(script_path: str, design_dir: Path) -> ValidatorResult:
    completed = subprocess.run(
        [sys.executable, script_path, "--design-dir", str(design_dir)],
        check=False,
        capture_output=True,
        text=True,
    )
    stdout = completed.stdout.strip()
    stderr = completed.stderr.strip()
    output = stdout if not stderr else f"{stdout}\n{stderr}".strip()
    warning_count = sum(1 for line in output.splitlines() if line.startswith("WARN:"))
    error_count = sum(1 for line in output.splitlines() if line.startswith("FAIL:"))
    result_line = next((line.strip() for line in output.splitlines() if line.startswith("RESULT:")), "")

    if result_line == "RESULT: FAIL":
        status = "FAIL"
    elif result_line == "RESULT: PASS" and warning_count > 0:
        status = "WARN"
    elif result_line == "RESULT: PASS":
        status = "PASS"
    else:
        raise RuntimeError(f"Validator did not produce a parseable RESULT line: {script_path}\n{output}")

    if completed.returncode not in {0, 1}:
        raise RuntimeError(f"Validator exited unexpectedly ({completed.returncode}): {script_path}\n{output}")

    return ValidatorResult(
        status=status,
        warning_count=warning_count,
        error_count=error_count,
        stdout=output,
        returncode=completed.returncode,
    )


def resolve_validator_results(design_dir: Path, run_validators: bool) -> dict[str, ValidatorResult]:
    if not run_validators:
        return {}

    results: dict[str, ValidatorResult] = {}
    seen: set[str] = set()
    for spec in ARTIFACT_SPECS:
        script_path = spec.validator_script
        if not script_path or script_path in seen or spec.default_validator_status == "SOURCE_ONLY":
            continue
        seen.add(script_path)
        results[script_path] = run_validator(script_path, design_dir)
    return results


def build_manifest_rows(design_dir: Path, validator_results: dict[str, ValidatorResult]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for spec in ARTIFACT_SPECS:
        artifact_path = design_dir / spec.filename
        if not artifact_path.exists():
            raise FileNotFoundError(f"Missing required artifact for manifest generation: {artifact_path}")

        if spec.default_validator_status == "SOURCE_ONLY":
            validator_status = "SOURCE_ONLY"
            warning_count = 0
            error_count = 0
        elif spec.validator_script in validator_results:
            result = validator_results[spec.validator_script]
            validator_status = result.status
            warning_count = result.warning_count
            error_count = result.error_count
        else:
            validator_status = spec.default_validator_status
            warning_count = 0
            error_count = 0

        rows.append(
            {
                "manifest_id": MANIFEST_ID,
                "package_version": PACKAGE_VERSION,
                "artifact_id": spec.artifact_id,
                "artifact_type": spec.artifact_type,
                "artifact_path": display_path(artifact_path),
                "source_stage": spec.source_stage,
                "generator_script": spec.generator_script,
                "validator_script": spec.validator_script,
                "required_inputs": ",".join(spec.required_inputs),
                "depends_on_artifacts": ",".join(spec.depends_on_artifacts),
                "row_count": str(count_rows(artifact_path)),
                "checksum_sha256": sha256_file(artifact_path),
                "validator_status": validator_status,
                "validator_warning_count": str(warning_count),
                "validator_error_count": str(error_count),
                "is_runtime_ready": "true" if spec.is_runtime_ready else "false",
                "export_scope": spec.export_scope,
                "export_blockers": ",".join(spec.export_blockers),
                "notes": spec.notes,
            }
        )
    return rows


def main() -> int:
    args = parse_args()
    design_dir = Path(args.design_dir)
    out_path = Path(args.out)

    validator_results = resolve_validator_results(design_dir, args.run_validators)
    rows = build_manifest_rows(design_dir, validator_results)
    write_tsv(out_path, rows)

    print(f"Wrote {out_path} with {len(rows)} artifacts.")
    if args.run_validators:
        for script_path, result in sorted(validator_results.items()):
            print(
                f"VALIDATOR: {script_path} -> {result.status} "
                f"(warn={result.warning_count}, fail={result.error_count})"
            )
    else:
        print("Validators were not run; generated artifacts use validator_status=NOT_RUN by default.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
