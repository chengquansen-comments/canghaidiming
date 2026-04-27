# v0.4.3 pressure_profile 压力规则

> 目标：在非对称 / 反应式结算下，为玩家提供持续压力。  
> 原则：压力是“这场遭遇”的节奏设计，因此配置在 `story_encounters.tsv`，而不是写入 fighter template / deck / stat。

---

## 1. 配置位置

文件：

```text
data/story_battles/story_encounters.tsv
```

新增字段：

```text
pressure_profile
```

示例：

```tsv
encounter_id	...	settlement_mode	pressure_profile	notes
prologue_beach_pressure	...	reactive	edge_pressure	测试逼身压力
prologue_beach_break	...	reactive	break_resist	测试崩势教学，精英稳势
```

---

## 2. 当前支持的 profile

| profile | 说明 |
|---|---|
| `none` | 无额外压力规则 |
| `edge_pressure` | 边界压迫：被逼至 0 位或 8 位时额外失 1 势 |
| `break_resist` | 精英稳势：对手第一次被打入 pending 崩势时，保留 1 势并抵消本次崩势中断 |

---

## 3. `edge_pressure`

### 规则

9 格轴中：

```text
0 位 = 左边界
8 位 = 右边界
```

当任意一方进入边界时：

```text
额外失 1 势
```

如果因此势变为 0：

```text
进入 pending 崩势
```

同一回合、同一角色、同一边界位置只触发一次，避免 UI 多次刷新导致重复扣势。

### 设计意图

用于制造：

```text
被枪顶到边缘
被刀压到无路可退
9格小空间里的站位压力
```

### 适合 encounter

```text
枪手控距
刀客逼身
反应式压力战
```

---

## 4. `break_resist`

### 规则

对手拥有 1 次“稳势”。

当对手第一次被打入：

```text
pending_control_state == CONTROL_BROKEN
```

时：

```text
取消本次 pending 崩势
对手势保留为 1
本次崩势中断不生效
```

### 设计意图

用于限制 reactive 下的无脑打断：

```text
玩家仍然可以打崩普通敌
但精英敌第一次会强行稳住
玩家需要二次破势，或转为躲避/控距
```

### 适合 encounter

```text
精英敌
高手对决
崩势教学后的进阶战
```

---

## 5. 当前接入位置

运行层在：

```text
scripts/battle_controller_visual_story_return.gd
```

该脚本继承：

```text
scripts/battle_controller_visual_settlement_mode.gd
```

并负责：

```text
1. 战斗结束自动回剧情遭遇选择
2. pressure_profile 运行时规则
```

---

## 6. 当前数据配置

| encounter_id | pressure_profile | 目的 |
|---|---|---|
| `prologue_beach_teach` | `none` | 第一场教学不额外加压 |
| `prologue_beach_pressure` | `edge_pressure` | 测试逼身和边界压力 |
| `prologue_beach_break` | `break_resist` | 测试崩势打断被抵消 |
| `prologue_spear_keep` | `edge_pressure` | 测试枪手控距与边界压迫 |
| `master_rescue_001` | `none` | 师傅救场演示，不额外干扰 |
| `symmetric_blade_duel` | `break_resist` | 高手刀客稳势 |
| `symmetric_spear_duel` | `edge_pressure` | 高手枪手边界压迫 |

---

## 7. 后续扩展候选

后续可继续加入：

| profile | 方向 |
|---|---|
| `range_pressure` | 敌方招式获得更宽威胁范围 |
| `corner_pusher` | AI 优先把玩家推向边界 |
| `timer_pressure` | 每 N 回合增强敌方伤害/削势 |
| `hidden_effect` | 精英敌隐藏部分附加效果 |
| `resource_pressure` | 玩家低势时移动范围下降 |

---

## 8. 调试检查

进入战斗后，如果 encounter 有压力规则，日志会显示：

```text
压力规则：edge_pressure
```

或：

```text
压力规则：break_resist
```

触发边界压迫时：

```text
边界压迫：我方/对手被逼至X位，额外失1势。
```

触发稳势时：

```text
稳势：对手强行稳住身形，本次崩势中断被抵消，势保留为1。
```
