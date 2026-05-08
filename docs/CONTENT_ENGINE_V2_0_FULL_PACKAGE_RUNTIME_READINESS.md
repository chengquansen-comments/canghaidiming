# Content Engine v2.0 full package runtime readiness audit

## 目标
从“全生成内容正式 enable”的终局倒推，对 7 个 domain 做 runtime readiness 审计。
本次仅输出 readiness 结论与 blockers，不导出 runtime，不改正式流程。

## 输出
- `data/design/generated_full_package_runtime_readiness.tsv`
- `data/design/generated_full_package_runtime_blockers.md`

## 审计维度
- preview 是否可用、数量是否正确
- candidate path 与 shadow compare 是否已验证
- runtime schema / adapter / fallback 是否具备
- formal enable 是否可放行（当前默认不放行）

## 结论使用方式
- 作为 v2.1 adapter 排期输入
- 作为后续受控 enable gate 的前置证据
