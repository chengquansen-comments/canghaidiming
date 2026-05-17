# 项目文档索引

本文档是 Markdown 入口。查规则先看“活跃总文档”，只有需要历史细节时再看附录或 `archive/`。

## 活跃总文档

| 文档 | 状态 | 负责范围 |
|---|---|---|
| [NARRATIVE.md](NARRATIVE.md) | 活跃 | 叙事 TSV、节点 flow、变量、剧情战斗触发 |
| [NARRATIVE_FLOW.md](NARRATIVE_FLOW.md) | 活跃 | 默认 flow、武举三锚点、AIGC 剧情池、海疆大势图、剧情战斗映射 |
| [BATTLE.md](BATTLE.md) | 活跃 | 战斗配置主源、结算模式、位移朝向、验证命令 |
| [UI_PIPELINE.md](UI_PIPELINE.md) | 活跃 | 视觉战斗 UI、大地图 overlay、预览、演出、缓存、Web UI |
| [ART_PIPELINE.md](ART_PIPELINE.md) | 活跃 | 美术素材目录、源图映射、资产验收 |
| [ART_REFERENCE_PROMPTS.md](ART_REFERENCE_PROMPTS.md) | 附录 | 参考图与提示词口径 |
| [ENGINEERING.md](ENGINEERING.md) | 活跃 | 代码组织、重构优先级、AI 协作、Godot 排障 |
| [web_refactor_progress.md](web_refactor_progress.md) | 活跃 | Web 化当前状态、验收缺口和已知问题基线 |

## 规则冲突优先级

1. 运行代码和 TSV 源表。
2. 上面的活跃总文档。
3. 专项附录。
4. `archive/` 与旧执行清单。

如果旧文档和活跃总文档冲突，以活跃总文档为准；如果总文档和代码冲突，以当前代码为准，并同步修文档。

## 专项附录

| 文档 | 当前定位 |
|---|---|
| [CODE_ORGANIZATION.md](CODE_ORGANIZATION.md) | 代码组织原则归档，核心口径已并入 [ENGINEERING.md](ENGINEERING.md) |
| [REFACTOR_BACKLOG.md](REFACTOR_BACKLOG.md) | 重构待办归档，当前优先级已并入 [ENGINEERING.md](ENGINEERING.md) |
| [chatgpt_debugging_rules.md](chatgpt_debugging_rules.md) | AI / Godot 排障归档，核心口径已并入 [ENGINEERING.md](ENGINEERING.md) |
| [single_battle_rules_current.md](single_battle_rules_current.md) | 战斗详细规则归档，核心口径已并入 [BATTLE.md](BATTLE.md) |
| [BATTLE_PRESENTATION_LAYER.md](BATTLE_PRESENTATION_LAYER.md) | 战斗演出层归档，核心口径已并入 [BATTLE.md](BATTLE.md) / [UI_PIPELINE.md](UI_PIPELINE.md) |
| [reactive_settlement_v040.md](reactive_settlement_v040.md) | 反应式结算早期设计案归档 |
| [balance_rules.md](balance_rules.md) | 旧卡牌预算公式归档 |
| [ENEMY_MANIFEST_RUNTIME.md](ENEMY_MANIFEST_RUNTIME.md) | 旧 enemy manifest 兼容归档 |
| [STANCE_PLACEHOLDER_DECKS.md](STANCE_PLACEHOLDER_DECKS.md) | 默认占位 encounter 归档 |
| [text_preview_stage_design.md](text_preview_stage_design.md) | 字符版站位预览归档 |
| [role_tactics.md](role_tactics.md) | 攻守变 role 归档 |
| [web_build_known_issues.md](web_build_known_issues.md) | Web 已知问题归档 |
| [../SPEARMAN_MIN_ACTION_PACKAGE_PLAN.md](../SPEARMAN_MIN_ACTION_PACKAGE_PLAN.md) | Spearman 最低动作包归档 |

## 历史执行清单

这些文档不再作为当前规则入口，只保留历史上下文：

| 文档 | 归属 |
|---|---|
| [symmetry_gameplay_v031_execution_list.md](symmetry_gameplay_v031_execution_list.md) | 对称战斗 v0.3.1 执行清单 |
| [carddata_movement_v032_change_list.md](carddata_movement_v032_change_list.md) | 卡牌位移 v0.3.2 执行清单 |
| [wuxia_battle_ui_godot_design.md](wuxia_battle_ui_godot_design.md) | 早期 UI 结构参考 |
| [ui_architecture_refactor.md](ui_architecture_refactor.md) | 早期 UI 拆层笔记 |

叙事旧稿、压缩脚本和历史进度已归档在 `archive/docs/narrative/`。

## 维护规则

- 新需求先更新对应活跃总文档，不新增平行总文档。
- 阶段性计划写短文档；完成后把结论并入总文档，计划文档降级为历史执行清单。
- 不在 README 重复长规则；README 只保留入口、命令和源表口径。
- 不直接改 `data/*.json` 来“修文档中的结果”；应改 TSV 后重新编译。
