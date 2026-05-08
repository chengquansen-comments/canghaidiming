# Content Engine v2.3 prologue_01 whitelist formal path

## 目标
在 `prologue_01` 白名单下，把 v2.2 runtime bridge 接到最小正式路径：仅 reward 允许 formal source=content_engine，其它 domain 仅 candidate 读取。

## 配置
- `data/design/generated_content_formal_enable_config.tsv`

## 新增验证
- `tools/content_engine/generated_content_formal_enable_probe.gd`
- `tools/content_engine/generated_content_formal_enable_validator.py`
- `data/design/generated_content_formal_enable_report.tsv`

## 边界
- 非白名单维持 legacy。
- `rollback_policy=legacy`。
- 不写 battle_state/combat_result/CardData。
- 不改 scene / battle core。
