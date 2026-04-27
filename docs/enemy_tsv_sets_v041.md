# v0.4.1 多 TSV 敌人套装系统

> 目标：用多份 TSV 快速生成、切换、比较多套敌人数值。  
> 原则：不改 CombatResolver，不把敌人数值写死在 GDScript 中。

---

## 1. 文件结构

```text
data/enemy_sets/
  enemy_sets_manifest.tsv
  enemies_base.tsv
  enemies_reactive_easy.tsv
  enemies_reactive_pressure.tsv
  enemies_symmetric_duel.tsv
scripts/enemy_set_loader.gd
```

---

## 2. manifest 字段

`enemy_sets_manifest.tsv` 用来登记敌人套装。

| 字段 | 说明 |
|---|---|
| `set_id` | 套装唯一 ID |
| `display_name` | UI 展示名 |
| `file` | 对应 TSV 文件 |
| `mode` | 推荐结算模式，`any/reactive/symmetric` |
| `description` | 说明 |
| `enabled` | 1 启用，0 隐藏 |

---

## 3. 敌人 TSV 字段

| 字段 | 说明 |
|---|---|
| `enemy_id` | 敌人唯一 ID |
| `display_name` | 展示名 |
| `weapon_style` | 武器风格，如 `spearman/blademaster` |
| `max_hp` | 最大生命 |
| `max_momentum` | 最大势 |
| `starting_momentum` | 初始势 |
| `starting_realm` | 初始武境 |
| `qinggong` | 轻功移动范围 |
| `start_position` | 初始站位 |
| `start_facing` | 初始朝向 |
| `preferred_distances` | 偏好距离，如 `2,3` |
| `deck` | 起始牌组，如 `spear_thrust:2,spear_gate:1` |
| `ai_style` | AI 风格标签 |
| `aggression` | 进攻倾向 |
| `keep_distance` | 控距倾向 |
| `break_focus` | 削势倾向 |
| `guard_focus` | 防守倾向 |
| `move_bias` | 移动倾向 |
| `notes` | 备注 |

---

## 4. deck 写法

```text
card_id:数量,card_id:数量
```

示例：

```text
spear_thrust:2,spear_gate:2,spear_shunbu:1,guard_spear:1
```

加载时展开为多张 `CardData`，并调用 `duplicate_card()` 避免共享实例。

---

## 5. Loader 接口

`EnemySetLoader` 提供：

```gdscript
EnemySetLoader.load_manifest()
EnemySetLoader.load_enabled_manifest()
EnemySetLoader.find_set_row(set_id)
EnemySetLoader.load_enemy_set(set_id)
EnemySetLoader.load_first_enemy_data(set_id, card_catalog)
EnemySetLoader.enemy_row_to_fighter_data(row, card_catalog)
EnemySetLoader.parse_deck(deck_text, card_catalog)
EnemySetLoader.parse_preferred_distances(text)
```

注意：第一版 Loader 不直接依赖项目里的卡牌数据库实现，而是接收外部传入的 `card_catalog: Dictionary`。

---

## 6. 当前已提供的套装

| set_id | 用途 |
|---|---|
| `base` | 默认基础敌人 |
| `reactive_easy` | 反应式简单敌人，适合测试看招破解 |
| `reactive_pressure` | 反应式压迫敌人，适合测试崩势打断和压力 |
| `symmetric_duel` | 对称式高手敌人，适合测试双向拆招 |

---

## 7. 推荐开局流程

```text
选择结算模式
→ 选择敌人套装
→ 选择兵器
→ 开始战斗
```

短期可以只取套装第一名敌人：

```gdscript
var enemy_data := EnemySetLoader.load_first_enemy_data(enemy_set_id, card_catalog)
```

后续再扩展为：

```text
随机敌人
按节点选择敌人
按难度权重抽敌人
调参面板热切换
```

---

## 8. 后续接入清单

1. 在开局 overlay 增加敌人套装选择。
2. 在 battle controller 中新增 `enemy_set_id`。
3. 根据 `enemy_set_id` 加载第一名敌人并替换当前敌方 FighterData。
4. 调参面板显示当前套装。
5. 自动对局采样支持按 `enemy_set_id` 批量跑。

---

## 9. 设计边界

第一版只做数值和牌组切换，不做：

```text
地图节点敌人池
随机权重
复杂 AI 行为树
运行时热重载
```

这些后续可以在当前 TSV 结构上扩展。
