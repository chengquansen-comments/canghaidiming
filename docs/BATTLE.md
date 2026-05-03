# 《大明之沧海嘀鸣》战斗总文档

本文档是当前战斗工作的唯一活跃入口。旧战斗文档保留为细节附录或历史记录；若旧文档、早期设计与当前代码冲突，以本文档、`docs/NARRATIVE.md` 和运行代码为准。

## 当前结论

战斗运行链路：

```text
叙事 TSV / 战斗测试入口
→ encounter_id
→ data/story_battles.json
→ scripts/story_battle_loader.gd
→ scenes/MainVisual.tscn
→ battle_controller_visual_* wrapper
→ scripts/battle_controller_core.gd
```

正式剧情战斗的敌我数值与卡组不再以 `enemy_manifest` 为主源。当前主源是 `data/story_battles/*.tsv`，由 `scripts/compile_tables.py` 编译到 `data/story_battles.json` 后运行读取。

## 活跃入口

### 运行场景

```text
scenes/MainVisual.tscn
```

当前场景默认：

```text
settlement_mode_id = "reactive"
```

视觉版战斗入口在桌面 / Web launcher 中显示为“战斗测试”。进入后列出 `data/story_battles/story_encounters.tsv` 的全部 encounter；从这里进入战斗后，debug 的“返回剧情”会回到战斗测试列表。

### 视觉控制器链

```text
scripts/battle_controller_visual_story_return.gd
→ scripts/battle_controller_visual_settlement_mode.gd
→ scripts/battle_controller_visual_preview_position_guard.gd
→ scripts/battle_controller_visual_presentation_mode_aware.gd
→ scripts/battle_controller_visual_presentation_stepwise.gd
→ scripts/battle_controller_visual_presentation.gd
→ scripts/battle_controller_visual_scene_manifest.gd
→ scripts/battle_controller_visual_narrative_formal.gd
→ scripts/battle_controller_visual_narrative_context.gd
→ scripts/battle_controller_visual_break_preview.gd
→ scripts/battle_controller_visual_resolver_preview.gd
→ scripts/battle_controller_visual_hot_tuning.gd
→ scripts/battle_controller_visual_tuning_panel.gd
→ scripts/battle_controller_visual_preview_checked.gd
→ scripts/battle_controller_visual_responsive_ui.gd
→ scripts/battle_controller_visual_cached_ui.gd
→ scripts/battle_controller_visual_ui.gd
→ scripts/battle_controller_demo_visual.gd
→ scripts/battle_controller_core.gd
```

各层原则：核心结算只写在 core / state machine / resolver；视觉 wrapper 负责入口、预览、调参、表演、叙事回流，不应直接制造和真实结算不一致的新战斗结果。

数值原则：除非用户明确提出，否则不要引入新的数值线、成长线、资源线或隐藏倍率。调平衡时优先使用已有的表字段、已有卡牌、已有职业 profile、已有成长奖励和已有 `pressure_profile`；若确实需要新增字段或规则，必须先说明它解决的具体问题，并等用户确认。

## 配置主源

### 剧情触发

剧情只负责“在哪个节点触发哪场战斗”：

```text
tables/narrative_mvp_prologue_steps.tsv
tables/narrative_mvp_nodes.tsv
```

战斗字段写在 `combat_json` 或 choice 的 `combat` 中：

```json
{
  "enabled": true,
  "encounter_id": "enc_ch2_reed_ambush",
  "battle_id": "chapter2_reed_ambush",
  "override_player_profile": true
}
```

字段含义：

| 字段 | 含义 |
|---|---|
| `encounter_id` | 战斗配置 id，必须存在于 `data/story_battles/story_encounters.tsv` |
| `battle_id` | 视觉场景 id，必须存在于 `tables/battle_scene_manifest.tsv` |
| `override_player_profile` | 是否用剧情主角的选择与成长覆写 StoryBattle 中的玩家配置 |

`override_player_profile=false` 适合序章师父救场等“玩家槽位其实是剧情角色”的战斗；主角亲自参战的剧情战一般为 `true`。

### 战斗配置

正式敌我数值、卡组和模式在这里维护：

```text
data/story_battles/fighter_templates.tsv
data/story_battles/fighter_stat_sets.tsv
data/story_battles/story_deck_sets.tsv
data/story_battles/story_encounters.tsv
```

职责：

| 表 | 职责 |
|---|---|
| `fighter_templates.tsv` | 角色模板、武器类型、默认站位、默认朝向 |
| `fighter_stat_sets.tsv` | 血量、势上限、初始势、武境、轻功 |
| `story_deck_sets.tsv` | 卡组方案，引用已有 card id |
| `story_encounters.tsv` | 一场战斗如何组合敌我模板、数值、卡组、结算模式、压力规则 |

运行时 `StoryBattleLoader` 读取的是 `data/story_battles.json`。不要直接改 JSON；改 TSV 后运行编译。

### 场景与背景

```text
tables/battle_scene_manifest.tsv
→ data/battle_scene_manifest.json
```

`battle_id` 只负责视觉场景、背景、镜头和标签，不负责敌我数值卡组。

### 卡牌数值

`story_deck_sets.tsv` 只引用 card id，不定义招式牌的伤害、耗势、位移等数值。当前卡牌数值仍来自：

```text
scripts/card_data.gd
scripts/battle_controller_core.gd::_build_catalog()
```

后续若要把招式牌完全表驱动，应单独迁移卡牌定义，而不是把卡牌数值塞进 encounter。

### enemy_manifest 现状

`tables/enemy_manifest_*.tsv` / `data/enemy_manifest.json` 是旧剧情战斗与 AI / debug 兼容层，不再是正式剧情战斗敌人数值、卡组的主源。新增或调整剧情战斗时优先改 `data/story_battles/*.tsv`。

## 配置流程

新增或调整一场剧情战斗：

```text
1. 在 data/story_battles/fighter_templates.tsv 补角色模板。
2. 在 data/story_battles/fighter_stat_sets.tsv 补数值方案。
3. 在 data/story_battles/story_deck_sets.tsv 补卡组方案。
4. 在 data/story_battles/story_encounters.tsv 组合成 encounter。
5. 在 tables/battle_scene_manifest.tsv 补 battle_id 的视觉场景。
6. 在 tables/narrative_mvp_*.tsv 的 combat_json / choice.combat 中引用 encounter_id、battle_id、override_player_profile。
7. 运行 python3 scripts/compile_tables.py。
8. 从“战斗测试”或剧情节点进入验证。
```

默认原则：新生产的战斗若无明确约束，优先使用占位牌组与数值方案（见 `docs/STANCE_PLACEHOLDER_DECKS.md`）；仅在需求明确指定其他方案时覆盖。

轻功是硬约束：基础数值最小值为 `1`。除非未来某张特殊招式牌明确写了临时效果，否则配置和热调都不应把轻功调到 `0`。

调整数值时默认只在现有管线内工作：改 `fighter_stat_sets.tsv`、`story_deck_sets.tsv`、`story_encounters.tsv`、职业初始 profile、正式剧情奖励或 F9 调参配置。不要为了修一个战斗强弱问题新增新的职业成长轴、新资源、新难度倍率或额外结算分支，除非用户主动提出或明确批准。

## 结算模式

当前保留两套模式：

| 模式 | id | 状态 |
|---|---|---|
| 反应式 | `reactive` | 当前默认；正式剧情战斗优先使用 |
| 对称式 | `symmetric` | 保留用于对照和旧规则测试 |

### 反应式流程

```text
回合开始浮窗
→ 敌方预移动 / 意图展示
→ 敌方移动动画完成
→ 玩家看到可移动范围
→ 玩家选择目标位置与朝向
→ 玩家选择招式并确认
→ 玩家攻击结算与表演
→ 若敌人未被崩势 / 打断，等待 0.2s
→ 敌人攻击结算与表演
→ 回合结束
```

关键规则：

- 反应式中，玩家必须等敌人回合初移动完成后，才看到可移动范围并选择移动目标。
- 玩家攻击如果把敌人打到 `CONTROL_BROKEN`，敌人本回合行动应被中断；预览和表演也必须尊重这一点。
- 敌人攻击动画必须在我方攻击动画完成后再延迟约 `0.2s` 开始。

### 对称式边界

对称式仍用于比较“双方同时提交意图”的玩法，但它与反应式的预移动、分段表演差异很大。改动时应隔离两套逻辑，避免为了某一模式的展示修复破坏另一套真实结算。

## 位移、朝向与预览

战斗轴为 9 格：

```text
0 1 2 3 4 5 6 7 8
```

默认站位：

| 阵营 | 默认位置 | 默认朝向 |
|---|---:|---|
| 我方 | 2 | right |
| 敌方 | 6 | left |

规则：

- 玩家选择目标位置后，实像从原始位置移动到目标位置。
- 若移动方向与朝向相反，应表现为退着走。
- 移动结束后如目标朝向变化，再播放转向。
- 选择目标位置后仍允许改选其他合法位置；撤销移动可瞬间回到原始位置和原始朝向。
- 攻击方向线不应出现。箭头只在敌我招式有位移效果时出现，从目标位置指向双方位移效果叠加后的预期位置。

## 表演节奏

表演层目标是让玩家看清“当前谁在行动、这段该看谁、行动何时结束”。

当前节奏口径：

```text
回合开始：第 N 回合浮窗约 0.5s
敌方意图：回合浮窗结束后约 0.1s 再展示
我方可行动：我方淡蓝轮廓光
确认出招：我方攻击表演
我方攻击结束：轮廓光消失，空约 0.2s
敌方行动：敌方红色轮廓光，意图气泡短暂放大/描边
敌方攻击与收集动画结束：红光消失，空约 0.1s
下一回合：播放第 N+1 回合浮窗
```

相关常量目前在 `scripts/battle_controller_visual_presentation_stepwise.gd`，包括：

```text
PRESENTATION_ENEMY_ATTACK_START_DELAY_AFTER_PLAYER := 0.20
```

表演层不得提前显示行动终点；角色应从当前实像位置移动到目标位置。

## 调参与采样

调参入口在视觉战斗 debug / hot tuning 层：

```text
scripts/battle_controller_visual_tuning_panel.gd
scripts/battle_controller_visual_hot_tuning.gd
```

当前目标：

- 游戏内可生成、删除、切换多套数值。
- 目标是具体战斗配置：招式牌、血量、轻功、卡组，而不是抽象倍率。
- 采样必须绑定当前战斗 / 当前 encounter / 当前敌我卡组，不应退回原始刀和枪默认样本。
- 自动采样显示胜率结果；优化目标应有所区分，不等于“一键自动优化”。

## 验证命令

常用：

```bash
python3 scripts/compile_tables.py
godot --headless --quit res://scenes/MainVisual.tscn
godot --headless --quit res://scenes/NarrativeDemo.tscn
```

战斗专项：

```bash
godot --headless --script tools/smoke_battle_test_return.gd
godot --headless --script tools/smoke_narrative_battle_call_override.gd
godot --headless --script tools/smoke_narrative_story_loader_migration.gd
godot --headless --script tools/smoke_prologue_master_loadout.gd
```

数值管线：

```bash
godot --headless --path . --script res://tools/smoke_battle_number_profiles.gd
godot --headless --path . --script res://tools/sample_story_battle_numbers.gd -- --samples=120 --seed=260430 --profile-mode=story_table
godot --headless --path . --script res://tools/sample_story_battle_numbers.gd -- --samples=120 --seed=260430 --profile-mode=narrative_progression --player-role=spearman
godot --headless --path . --script res://tools/sample_story_battle_numbers.gd -- --samples=120 --seed=260430 --profile-mode=narrative_progression --player-role=blademaster
```

`story_table` 用 `story_encounters.tsv` 里的玩家 stat/deck 原样采样，适合检查战斗测试列表的裸配置。
`narrative_progression` 会模拟剧情主角 profile 覆写与胜利成长，适合检查正式剧情养成线。
同一场战斗在两种口径下可能强弱相反；调表前应先确认目标是“裸配置测试”还是“正式剧情职业成长”。

Godot headless 可能输出已有 RID leak 警告；只要命令退出码为 0，通常不代表本次改动失败。

## 旧文档定位

| 文档 | 当前定位 |
|---|---|
| `docs/single_battle_rules_current.md` | 详细规则附录 |
| `docs/BATTLE_PRESENTATION_LAYER.md` | 表演层细节附录 |
| `docs/reactive_settlement_v040.md` | 反应式早期设计案 / 历史参考 |
| `docs/wuxia_battle_ui_godot_design.md` | UI 早期结构参考 |
| `docs/balance_rules.md` | 旧卡牌预算参考 |
| `docs/ENEMY_MANIFEST_RUNTIME.md` | 旧 manifest 运行时参考 |
