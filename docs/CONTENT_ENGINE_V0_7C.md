# Content Engine v0.7c

## 1) v0.7c 定位

v0.7c 是 manual approval overlay / waiver process。
本阶段只在 design layer 上叠加人工审批结果，不是 runtime exporter。

## 2) 与 v0.7b / v0.7d / v0.8 的边界

- v0.7b：runtime export dry-run，输出全域 blocker 与基础导出条件，不做人工放行。
- v0.7c：在 dry-run 结果上叠加人工审批，得到最小可控 `would_export=true` 候选。
- v0.7d：做 dry-run 与 overlay diff 报告，检查审批影响面。
- v0.8：仅在有明确 approved PASS artifact 后，才可进入 runtime exporter 实现讨论。

## 3) 输入与输出

输入：

- `data/design/generated_runtime_export_dry_run.tsv`
- `data/design/runtime_export_approval.tsv`

输出：

- `data/design/generated_runtime_export_approval_overlay.tsv`
- `data/design/generated_runtime_export_approval_overlay.md`

## 4) 人工审批流程

`runtime_export_approval.tsv` 以 `runtime_domain + artifact_id` 为人工审批主键，逐条填写：

- `validator_status`
- `approval_status`（pending / approved / rejected）
- `approved_for_export`（true / false）
- `waiver_flags`
- `waiver_status`（none / pending / cleared / rejected / unresolved）
- `approved_by`
- `approved_at`
- `approval_notes`

建议只批准小批量低风险样本，保持最小可控变更面。

## 5) waiver 清理流程

对 WARN 或带 `waiver_flags` 的 artifact：

1. 先标注 `waiver_status=pending` 或 `unresolved`。
2. 完成人工核查后，清空 `waiver_flags`。
3. 仅在 `waiver_status=cleared`（或 `none`）时再考虑放行。

## 6) 何时可以 would_export=true

对某个 runtime_domain，其全部 source artifact 必须同时满足：

- `validator_status == PASS`
- `approval_status == approved`
- `approved_for_export == true`
- `waiver_flags` 为空
- `waiver_status` 不是 pending / unresolved / rejected
- 记录可被 dry-run 识别（`runtime_domain + artifact_id` 匹配）

## 7) 何时必须 blocked

出现任意一项即 blocked=true：

- `not_manually_approved`
- `approval_status_not_approved`
- `approved_for_export_not_true`
- `validator_status_not_pass`
- `waiver_flags_present`
- `waiver_not_cleared`
- `approval_record_missing`
- `approval_record_unknown_to_dry_run`

## 8) 本阶段不做什么

- 不实现 runtime exporter
- 不写入 `data/runtime/content_engine/`
- 不写 runtime JSON
- 不修改任何 Godot 运行时逻辑文件

## 9) 运行命令

```bash
python tools/content_engine/runtime_export_approval_overlay.py \
  --design-dir data/design \
  --approval-tsv data/design/runtime_export_approval.tsv \
  --out data/design/generated_runtime_export_approval_overlay.tsv \
  --out-md data/design/generated_runtime_export_approval_overlay.md
```

```bash
python tools/content_engine/runtime_export_approval_validator.py \
  --design-dir data/design
```
