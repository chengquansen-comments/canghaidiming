# v0.4.2 剧情战斗配置系统

> 目标：将《沧海嘀鸣》的剧情战斗配置拆成“战斗单位模板 / 剧情卡组 / 数值套装 / 剧情遭遇”四层。  
> 核心原则：模板不分敌我，卡组不分敌我，数值套装不分敌我，只有 encounter 分敌我。

---

## 1. 文件结构

```text
data/story_battles/
  fighter_templates.tsv
  story_deck_sets.tsv
  fighter_stat_sets.tsv
  story_encounters.tsv
scripts/story_battle_loader.gd
```

`data/enemy_sets/` 保留为 sandbox 调参池；正式剧情战斗配置优先使用 `data/story_battles/`。

---

## 2. 四层职责

| 层级 | 文件 | 职责 | 是否区分敌我 |
|---|---|---|---|
| 战斗单位模板 | `fighter_templates.tsv` | 定义这个战斗单位是谁、默认武器、默认站位、默认朝向 | 否 |
| 剧情卡组 | `story_deck_sets.tsv` | 定义某个战斗单位在某个剧情版本使用哪些招式 | 否 |
| 数值套装 | `fighter_stat_sets.tsv` | 定义生命、势、武境、轻功等数值强度 | 否 |
| 剧情遭遇 | `story_encounters.tsv` | 定义一场战斗里谁是我方、谁是对手、用哪套卡组/数值/结算模式 | 是 |

---

## 3. 关系图

```text
story_encounters.tsv
  ├─ player_template_id ───────┐
  ├─ player_deck_id ───────────┼─> build player FighterData
  ├─ player_stat_set_id ───────┘
  │
  ├─ opponent_template_id ─────┐
  ├─ opponent_deck_id ─────────┼─> build opponent FighterData
  ├─ opponent_stat_set_id ─────┘
  │
  └─ settlement_mode ───────────> BattleStateMachine settlement mode
```

---

## 4. `fighter_templates.tsv`

### 作用

定义“这个战斗单位是谁”。它不定义此单位是玩家、敌人还是友军。

### 字段

| 字段 | 说明 |
|---|---|
| `fighter_template_id` | 战斗单位模板唯一 ID |
| `display_name` | 展示名 |
| `weapon_style` | 武器风格，如 `spearman` / `blademaster` |
| `default_position` | 默认站位 |
| `default_facing` | 默认朝向，`left` / `right` |
| `story_role` | 剧情角色定位 |
| `notes` | 备注 |

### 示例

```tsv
fighter_template_id	display_name	weapon_style	default_position	default_facing	story_role	notes
player_blademaster	少年刀客	blademaster	2	right	玩家单位	主角刀客模板
prologue_blade_recruit	倭刀喽啰	blademaster	6	left	海边初战教学单位	普通倭寇刀手
master_veteran	退伍老兵	spearman	2	right	师傅单位	救场与教学角色
```

---

## 5. `story_deck_sets.tsv`

### 作用

定义某个战斗单位在某个剧情版本里使用哪些招式。

同一个 `fighter_template_id` 可以对应多套 `story_deck_id`，用于测试不同剧情节奏。

### 字段

| 字段 | 说明 |
|---|---|
| `story_deck_id` | 剧情卡组唯一 ID |
| `display_name` | 展示名 |
| `fighter_template_id` | 适用的战斗单位模板 |
| `deck` | 卡组配置，格式为 `card_id:数量,card_id:数量` |
| `tags` | 标签，如 `teaching` / `pressure` / `break_focus` |
| `notes` | 备注 |

### deck 写法

```text
blade_cut:2,blade_press:2,blade_probe:1
```

表示：

```text
blade_cut × 2
blade_press × 2
blade_probe × 1
```

`deck` 只能引用当前主线中已存在的 `CardData.id`。TSV 不负责定义新卡。

---

## 6. `fighter_stat_sets.tsv`

### 作用

定义战斗单位在一场战斗中的数值强度。

### 字段

| 字段 | 说明 |
|---|---|
| `stat_set_id` | 数值套装唯一 ID |
| `display_name` | 展示名 |
| `max_hp` | 最大生命 |
| `max_momentum` | 最大势 |
| `starting_momentum` | 初始势 |
| `starting_realm` | 初始武境 |
| `qinggong` | 轻功移动范围 |
| `notes` | 备注 |

### 示例

```tsv
stat_set_id	display_name	max_hp	max_momentum	starting_momentum	starting_realm	qinggong	notes
easy	简单	18	6	4	1	1	教学用
pressure	压迫	26	8	6	2	1	高压敌人
master	师傅	32	10	8	3	1	师傅救场演示
```

---

## 7. `story_encounters.tsv`

### 作用

定义一场剧情战斗。只有这一层区分我方和对手。

### 字段

| 字段 | 说明 |
|---|---|
| `encounter_id` | 剧情遭遇唯一 ID |
| `display_name` | 展示名 |
| `player_template_id` | 我方模板 |
| `player_deck_id` | 我方剧情卡组 |
| `player_stat_set_id` | 我方数值套装 |
| `opponent_template_id` | 对手模板 |
| `opponent_deck_id` | 对手剧情卡组 |
| `opponent_stat_set_id` | 对手数值套装 |
| `settlement_mode` | 结算模式，`symmetric` / `reactive` |
| `notes` | 备注 |

### 示例

```tsv
encounter_id	display_name	player_template_id	player_deck_id	player_stat_set_id	opponent_template_id	opponent_deck_id	opponent_stat_set_id	settlement_mode	notes
prologue_beach_teach	海边初战·教学	player_blademaster	player_blade_start	player_start	prologue_blade_recruit	prologue_blade_teach	easy	reactive	第一场教学战
```

---

## 8. 当前开局流程

当前 `MainVisual` 开局流程为：

```text
选择剧情遭遇
→ encounter 自动决定双方 FighterData 与 settlement_mode
→ 进入战斗
```

不再需要手动选择：

```text
结算模式
敌人套装
兵器
```

如果需要临时测试结算模式，仍可在战斗中按 `F8` 切换。

---

## 9. Loader 行为

`StoryBattleLoader.build_story_battle(encounter_id, card_catalog)` 返回：

```gdscript
{
  "encounter": encounter_row,
  "player_data": FighterData,
  "opponent_data": FighterData,
  "settlement_mode": "reactive" 或 "symmetric"
}
```

`battle_controller_visual_settlement_mode.gd` 会用返回结果替换当前玩家与对手，并设置 `BattleStateMachine` 的结算模式。

---

## 10. 修改规则

### 想改某个角色是谁

改：

```text
data/story_battles/fighter_templates.tsv
```

### 想改某个剧情版本下角色用什么牌

改：

```text
data/story_battles/story_deck_sets.tsv
```

### 想改血量、势、武境、轻功

改：

```text
data/story_battles/fighter_stat_sets.tsv
```

### 想改一场战斗双方是谁、用哪套卡、什么结算模式

改：

```text
data/story_battles/story_encounters.tsv
```

### 想新增一张招式牌

先改主线 `CardData` 定义；确认 `CardData.id` 存在后，再允许 `story_deck_sets.tsv` 引用。

---

## 11. 禁止事项

```text
1. 不要在 fighter_templates.tsv 中区分敌我。
2. 不要在 story_deck_sets.tsv 中发明不存在的 CardData.id。
3. 不要在 fighter_stat_sets.tsv 中写剧情身份。
4. 不要在 story_encounters.tsv 外部决定谁是玩家、谁是对手。
5. 不要让 data/enemy_sets/ 重新变成正式剧情配置源。
```

---

## 12. 后续扩展

后续可以在当前结构上扩展：

```text
1. 支持多对手 encounters
2. 支持友军 side
3. 支持剧情节点奖励
4. 支持战斗胜利后自动进入下一剧情 encounter
5. 支持调参面板中切换 encounter_id
6. 支持自动对局按 encounter 批量采样
```

---

## 13. 当前结论

当前正式内容管线为：

```text
CardData 主线卡牌定义
→ story_deck_sets 引用卡牌
→ fighter_templates 定义战斗单位
→ fighter_stat_sets 定义数值强度
→ story_encounters 组合双方并指定结算模式
```

这套结构是后续剧情战斗、教学战斗、师傅救场、高手对决和参数扫描的基础。
