#!/usr/bin/env python3
"""v0.9c battle_reward runtime hydration（仅数据水合，不接入主流程）。"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path


SOURCE_TSV = Path("data/design/generated_battle_reward_plan.tsv")
RUNTIME_BATTLE_REWARD = Path("data/runtime/content_engine/battle_reward.json")
RUNTIME_MANIFEST = Path("data/runtime/content_engine/runtime_manifest.json")
CARD_POOL_PATH = Path("data/runtime/content_engine/card_pool.json")
RUNTIME_LOADER_CONFIG = Path("data/runtime/content_engine/runtime_loader_config.json")
REPORT_TSV = Path("data/design/generated_runtime_battle_reward_hydration_report.tsv")
REPORT_MD = Path("data/design/generated_runtime_battle_reward_hydration_report.md")
ALLOWED_RUNTIME_FILES = {
    "card_pool.json",
    "battle_reward.json",
    "runtime_manifest.json",
    "runtime_loader_config.json",
}
REPORT_FIELDS = [
    "runtime_domain",
    "source_design_path",
    "runtime_path",
    "source_record_count",
    "hydrated_record_count",
    "source_field_count",
    "hydrated_field_count",
    "previous_runtime_record_count",
    "previous_runtime_field_count",
    "previous_content_fingerprint",
    "new_content_fingerprint",
    "manifest_updated",
    "card_pool_unchanged",
    "runtime_loader_config_unchanged",
    "read_only_integration",
    "formal_data_source_replaced",
    "integration_status",
    "blocked_reason",
    "notes",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="执行 battle_reward runtime hydration。")
    parser.add_argument("--source", default=str(SOURCE_TSV))
    parser.add_argument("--runtime-battle-reward", default=str(RUNTIME_BATTLE_REWARD))
    parser.add_argument("--manifest", default=str(RUNTIME_MANIFEST))
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def read_json_dict(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{path} 必须是 JSON object")
    return payload


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def fingerprint_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def load_tsv_rows(path: Path) -> tuple[list[dict[str, str]], list[str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        fieldnames = reader.fieldnames or []
        rows = list(reader)
    return rows, fieldnames


def build_hydrated_payload(
    old_payload: dict,
    source_rows: list[dict[str, str]],
    source_fields: list[str],
) -> dict:
    schema_fingerprint = fingerprint_text("\n".join(source_fields))
    canonical = json.dumps(source_rows, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    content_fingerprint = fingerprint_text(canonical)
    field_union = sorted({k for row in source_rows for k in row.keys()})

    return {
        "runtime_domain": str(old_payload.get("runtime_domain", "battle_reward")),
        "artifact_id": str(old_payload.get("artifact_id", "generated_battle_reward_plan")),
        "export_version": "v0.9c",
        "source_design_path": str(old_payload.get("source_design_path", SOURCE_TSV.as_posix())),
        "schema_fingerprint": schema_fingerprint,
        "content_fingerprint": content_fingerprint,
        "record_count": len(source_rows),
        "field_count": len(field_union),
        "records": source_rows,
        "generated_by": "tools/content_engine/runtime_battle_reward_hydrator.py",
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "notes": "v0.9c hydration: battle_reward runtime records are hydrated from generated_battle_reward_plan.tsv.",
    }


def update_manifest(
    manifest: dict,
    runtime_payload: dict,
    runtime_path: Path,
) -> tuple[dict, bool]:
    files = manifest.get("files", [])
    if not isinstance(files, list):
        raise ValueError("runtime_manifest.json files 必须是数组")

    new_manifest = deepcopy(manifest)
    target_idx = -1
    for i, entry in enumerate(files):
        if not isinstance(entry, dict):
            continue
        if str(entry.get("runtime_domain", "")) == "battle_reward" and str(entry.get("file_name", "")) == "battle_reward.json":
            target_idx = i
            break
    if target_idx < 0:
        raise ValueError("runtime_manifest.json 未找到 battle_reward entry")

    old_entry = dict(files[target_idx])
    new_entry = dict(old_entry)
    new_entry["runtime_domain"] = "battle_reward"
    new_entry["artifact_id"] = str(runtime_payload.get("artifact_id", old_entry.get("artifact_id", "")))
    new_entry["runtime_path"] = "data/runtime/content_engine/battle_reward.json"
    new_entry["file_name"] = "battle_reward.json"
    new_entry["file_size_bytes"] = runtime_path.stat().st_size
    new_entry["sha256"] = sha256_file(runtime_path)
    new_entry["schema_fingerprint"] = str(runtime_payload.get("schema_fingerprint", ""))
    new_entry["content_fingerprint"] = str(runtime_payload.get("content_fingerprint", ""))
    new_entry["record_count"] = int(runtime_payload.get("record_count", 0))
    new_entry["field_count"] = int(runtime_payload.get("field_count", 0))
    new_entry["export_version"] = str(runtime_payload.get("export_version", old_entry.get("export_version", "")))
    new_entry["generated_at"] = str(runtime_payload.get("generated_at", old_entry.get("generated_at", "")))
    new_entry["source_design_path"] = str(runtime_payload.get("source_design_path", old_entry.get("source_design_path", "")))
    new_manifest["files"][target_idx] = new_entry
    new_manifest["generated_at"] = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    new_manifest["generated_by"] = "tools/content_engine/runtime_battle_reward_hydrator.py"

    return new_manifest, new_entry != old_entry


def main() -> int:
    args = parse_args()
    source_path = Path(args.source)
    runtime_path = Path(args.runtime_battle_reward)
    manifest_path = Path(args.manifest)
    out_tsv = Path(args.out)
    out_md = Path(args.out_md)

    blocked: list[str] = []

    for path in [source_path, runtime_path, manifest_path, CARD_POOL_PATH, RUNTIME_LOADER_CONFIG]:
        if not path.exists():
            raise FileNotFoundError(f"缺少必需文件：{path}")

    runtime_root = Path("data/runtime/content_engine")
    runtime_names = {p.name for p in runtime_root.iterdir() if p.is_file()} if runtime_root.exists() else set()
    if runtime_names != ALLOWED_RUNTIME_FILES:
        blocked.append("runtime_dir_not_allowlisted")

    card_pool_sha_before = sha256_file(CARD_POOL_PATH)
    config_sha_before = sha256_file(RUNTIME_LOADER_CONFIG)

    source_rows, source_fields = load_tsv_rows(source_path)
    previous_payload = read_json_dict(runtime_path)
    manifest_payload = read_json_dict(manifest_path)

    previous_runtime_record_count = int(previous_payload.get("record_count", 0))
    previous_runtime_field_count = int(previous_payload.get("field_count", 0))
    previous_content_fingerprint = str(previous_payload.get("content_fingerprint", ""))

    hydrated_payload = build_hydrated_payload(previous_payload, source_rows, source_fields)
    runtime_path.write_text(json.dumps(hydrated_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    new_manifest, manifest_changed = update_manifest(manifest_payload, hydrated_payload, runtime_path)
    manifest_path.write_text(json.dumps(new_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    # v0.9c 口径：只要 hydration 流程重写了 manifest，即视为已更新。
    manifest_updated = True

    card_pool_sha_after = sha256_file(CARD_POOL_PATH)
    config_sha_after = sha256_file(RUNTIME_LOADER_CONFIG)
    card_pool_unchanged = card_pool_sha_before == card_pool_sha_after
    runtime_loader_config_unchanged = config_sha_before == config_sha_after
    if not card_pool_unchanged:
        blocked.append("card_pool_changed")
    if not runtime_loader_config_unchanged:
        blocked.append("runtime_loader_config_changed")

    row = {
        "runtime_domain": "battle_reward",
        "source_design_path": source_path.as_posix(),
        "runtime_path": runtime_path.as_posix(),
        "source_record_count": str(len(source_rows)),
        "hydrated_record_count": str(int(hydrated_payload.get("record_count", 0))),
        "source_field_count": str(len(source_fields)),
        "hydrated_field_count": str(int(hydrated_payload.get("field_count", 0))),
        "previous_runtime_record_count": str(previous_runtime_record_count),
        "previous_runtime_field_count": str(previous_runtime_field_count),
        "previous_content_fingerprint": previous_content_fingerprint,
        "new_content_fingerprint": str(hydrated_payload.get("content_fingerprint", "")),
        "manifest_updated": "true" if manifest_updated else "false",
        "card_pool_unchanged": "true" if card_pool_unchanged else "false",
        "runtime_loader_config_unchanged": "true" if runtime_loader_config_unchanged else "false",
        "read_only_integration": "true",
        "formal_data_source_replaced": "false",
        "integration_status": "hydrated_not_integrated",
        "blocked_reason": ",".join(sorted(set(blocked))),
        "notes": (
            "v0.9c 仅做 battle_reward runtime hydration，不接入战斗奖励逻辑与主流程；"
            f"manifest_changed={str(manifest_changed).lower()}"
        ),
    }

    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=REPORT_FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerow(row)

    lines = [
        "# Runtime Battle Reward Hydration 报告",
        "",
        "## 目标",
        "",
        "- 本次目标是将 `battle_reward.json` 从空 scaffold 水合为来自 `generated_battle_reward_plan.tsv` 的真实 records。",
        "- 本阶段仍不接入正式奖励逻辑，不替换主流程数据源。",
        "",
        "## 输入与输出",
        "",
        f"- 输入源：`{source_path.as_posix()}`、`{runtime_path.as_posix()}`、`{manifest_path.as_posix()}`",
        f"- 输出文件：`{runtime_path.as_posix()}`、`{manifest_path.as_posix()}`、`{out_tsv.as_posix()}`、`{out_md.as_posix()}`",
        "",
        "## 关键变化",
        "",
        f"- source_record_count: {row['source_record_count']}",
        f"- hydrated_record_count: {row['hydrated_record_count']}",
        f"- previous_runtime_record_count: {row['previous_runtime_record_count']}",
        f"- previous_runtime_field_count: {row['previous_runtime_field_count']}",
        f"- hydrated_field_count: {row['hydrated_field_count']}",
        "",
        "## Fingerprint 与 Manifest",
        "",
        f"- previous_content_fingerprint: {row['previous_content_fingerprint']}",
        f"- new_content_fingerprint: {row['new_content_fingerprint']}",
        f"- manifest_updated: {row['manifest_updated']}",
        "",
        "## 不变性检查",
        "",
        f"- card_pool_unchanged: {row['card_pool_unchanged']}",
        f"- runtime_loader_config_unchanged: {row['runtime_loader_config_unchanged']}",
        "",
        "## 边界与后续",
        "",
        "- 本阶段仅修复 runtime 内容可比对性，避免在主流程接入前带着空 records 做对比。",
        "- 建议 v0.9d 再推进 battle_reward read-only Godot compare/probe，在 gate 约束下验证运行时读取行为。",
        "",
    ]
    out_md.write_text("\n".join(lines), encoding="utf-8")

    print(f"Wrote {out_tsv} and {out_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
