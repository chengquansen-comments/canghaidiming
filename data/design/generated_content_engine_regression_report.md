# Content Engine 回归报告

- 总体结果：PASS
- 步骤总数：39
- 必需步骤通过：35/35
- 必需步骤失败数：0

## 阶段汇总

- adapter_scaffold: 2/2 PASS
- compile: 1/1 PASS
- guarded_write: 1/2 PASS
- hygiene: 4/4 PASS
- manifest: 2/2 PASS
- negative_fixture: 3/3 PASS
- post_restore: 1/1 PASS
- preflight: 2/2 PASS
- preview: 7/10 PASS
- probe: 2/2 PASS
- runtime_test_harness: 2/2 PASS
- scaffold: 2/2 PASS
- shadow_freeze: 2/2 PASS
- shadow_plan: 2/2 PASS
- shadow_runtime: 2/2 PASS

## 失败步骤

- 3 runtime_export_dry_run_validator (required=false) exit=1
- 7 runtime_export_diff_report_validator (required=false) exit=1
- 9 runtime_exporter_preview_validator (required=false) exit=1
- 23 runtime_exporter_guarded_write_validator (required=false) exit=1

## Runtime 安全性摘要

- preview_formal_runtime_sha_unchanged: true
- preview_runtime_dir_allowed_only: true
- runtime_dir_allowed_only_end: true

## Manifest/Checksum 摘要

- runtime_export_manifest_validator_pass: true

## Loader/Probe 摘要

- runtime_loader_godot_probe_validator_pass: true
- runtime_loader_scaffold_validator_pass: true

## Negative Fixture 摘要

- runtime_loader_negative_fixture_validator_pass: true
- negative_fixture_match_all_matched: true
- negative_fixture_returned_domain_count_zero: true
- negative_fixture_write_api_present_false: true

## Godot Warning 摘要

- warning_detected: true
- 当 Godot 退出码为 0 时，warning 作为独立 hygiene issue 记录，不阻塞 content engine regression。

## 高风险文件

- scripts/card_data.gd 未修改
- scripts/battle_state_machine.gd 未修改
- scripts/combat_resolver.gd 未修改
- scenes/*.tscn 未修改
- data/story_battles/*.tsv 未修改
