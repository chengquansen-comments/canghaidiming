# 战斗数量、成长与结局路线完整方案 v1.3

## 一、总体目标

本方案同时控制五件事：

1. **总战斗数量**：决定单局长度与内容制作规模。
2. **武道十境成长速度**：普通路线 8-9 境，精英路线稳定 10 境。
3. **轻功成长稀缺性**：轻功上限 4，正常只能到 2，奇遇下可以到 4。
4. **大地图敌人池规模**：大地图实际打约 15 场，但敌人 / 卡组候选池约 2 倍。
5. **结局路线分化**：普通结局、真结局、武状元特殊结局分别对应不同 Boss / 战斗结构。

一句话：

> 普通玩家走完一局约 22-23 场战斗，达到 8-9 境可通普通结局；精英路线稳定 10 境，可进真结局；若在大地图满足武境 10、军功高等特殊条件，则触发回京武状元路线，额外进行 5 场考试战，获得武状元特殊结局。

---

## 二、完整战斗数量规划

### 1. 基础流程

| 阶段 | 战斗数 | 说明 |
|---|---:|---|
| 序章战 | 1 | 剧情教学 / 师父救场 |
| 武举线 | 5 | 含兵器使用 2 场 + 武举正式考核 3 场 |
| 大地图战斗 | 约 15 | 正式构筑、成长、旧案推进主体 |
| 普通结局 Boss | 1 | 8-9 境可通 |
| 真结局 Boss | 2 | Boss 1 + 真 Boss |
| 武状元路线 | 5 | 回京考试 5 战，特殊结局 |

### 2. 不同结局总战斗数

| 路线 | 构成 | 总战斗数 |
|---|---|---:|
| 普通结局 | 序章 1 + 武举 5 + 大地图 15 + 普通 Boss 1 | **约 22 场** |
| 真结局 | 序章 1 + 武举 5 + 大地图 15 + 真结局 Boss 2 | **约 23 场** |
| 武状元特殊结局 | 序章 1 + 武举 5 + 大地图 15 + 回京考试 5 | **约 26 场** |

大地图允许小幅浮动：

```text
大地图目标战斗数：15
允许浮动：14-16
成长曲线按 15 场测算
```

---

## 三、序章战，1 场

### 1. 定位

序章战是剧情与基础教学，不是正式构筑战。

承担：

- 战斗 UI 入门
- 血 / 势 / 距离基础感知
- 幼年旧案开端
- 倭寇表象
- 师父救场
- “不要看”的创伤记忆

### 2. 制作规则

| 项目 | 规则 |
|---|---|
| 战斗结果 | 剧情必败 / 半强制失败 / 师父介入 |
| 玩家卡组 | 固定教学卡组 |
| 敌人卡组 | tutorial_enemy_deck |
| 正式卡牌奖励 | 不给 |
| 武器选择 | 不给 |
| 成长收益 | 少量武道，不给轻功突破 |

推荐奖励：

```yaml
martial_xp: 3
weapon_xp: 0
lightness_reward_type: none
card_reward: none
```

---

## 四、武举线，5 场

武举线包含：

```text
兵器使用教学 2 场
武举正式考核 3 场
```

它的作用是让玩家从“会出牌”过渡到“会使用兵器、理解距离、进入正式构筑”。

### 1. 兵器使用教学，2 场

这 2 场在武举线内部，不再单独作为独立阶段。

| 战斗 | 主题 | 目标 |
|---|---|---|
| 武举兵器试一 | 长枪 | 理解距离 2-3、拒止、击退、削势 |
| 武举兵器试二 | 单刀 | 理解距离 1-2、进身、防反、爆发 |

制作规则：

```text
长枪战只教控线、削势、击退。
单刀战只教进身、防反、爆发。
不在这里加入连招、虚招、武境压制等复杂机制。
```

推荐奖励：

```yaml
martial_xp_each: 5
weapon_xp_each: 4
lightness_reward_type: practice
lightness_cap_unlock: none
card_reward: weapon_basic_card
```

### 2. 武举正式考核，3 场

| 战斗 | 主题 | 目标 |
|---|---|---|
| 武举一试 | 步法 / 距离 | 检查位移、控距、基础身法 |
| 武举二试 | 兵器 / 招式 | 检查主武器基础循环 |
| 武举三试 | 对人战 | 检查势、破招、节奏判断 |

推荐奖励：

| 战斗 | martial_xp | weapon_xp | 轻功 |
|---|---:|---:|---|
| 武举一试 | 5 | 1 | 可给轻功 1 |
| 武举二试 | 6 | 4 | 不突破 |
| 武举三试 | 8 | 3 | 不突破 |

武举线结束后的目标状态：

```text
累计战斗数：6 场
武道境界：第 3-4 境
轻功：0-1，最多不超过 1
主武器：基础成型
卡组：通用牌 + 主武器基础牌
```

---

## 五、大地图战斗规划

### 1. 实际体验数量

大地图每局实际经历：

| 路线 | 普通战 | 精英战 | 总战斗 | 定位 |
|---|---:|---:|---:|---|
| 普通路线 | 12 | 3 | 15 | 通普通结局，最终 8-9 境 |
| 标准路线 | 11 | 4 | 15 | 接近或达到 10 境 |
| 精英路线 | 10 | 5 | 15 | 稳定 10 境，真结局 / 武状元候选 |

精英比例：

```text
20%-30%
15 场中约 3-5 场精英
```

### 2. 大地图分段

| 段落 | 战斗编号 | 战斗数 | 精英数 | 功能 |
|---|---|---:|---:|---|
| 前段 | M01-M05 | 5 | 0-1 | 基础构筑检查 |
| 中段 | M06-M10 | 5 | 1-2 | 构筑分化 |
| 后段 | M11-M15 | 5 | 2 | Boss / 结局路线前压力测试 |

前段不放连续精英。  
中段开始出现双机制敌人。  
后段用于决定玩家是普通结局、真结局，还是触发武状元路线。

---

## 六、大地图敌人池与卡组池

### 1. 核心规则

大地图随机出敌人，为了提高重复可玩性：

```text
大地图敌人 / 卡组候选池 ≈ 实际体验战斗数量的 2 倍
```

实际体验约 15 场，所以候选池建议：

```text
大地图候选 battle slot / enemy deck：28-32 个
推荐默认：30 个
```

### 2. 候选池规模

| 类型 | 实际每局体验 | 候选池数量 |
|---|---:|---:|
| 普通敌人 | 10-12 | 20-24 |
| 精英敌人 | 3-5 | 8-10 |
| 稀有 / 事件战斗 | 0-1 | 2-3 |
| 合计 | 约 15 | 约 30 |

注意：这里的“敌人数量”优先指：

```text
enemy_archetype_variant
enemy_deck_id
battle_slot
```

不要求美术上做 30 套完全不同敌人。

### 3. 复用结构

推荐制作层级：

```text
视觉身份 < enemy_archetype < deck_variant < battle_slot
```

例如同一个“海寇刀客”视觉身份，可以派生：

```text
coastal_raider_blade_basic
coastal_raider_blade_aggressive
coastal_raider_blade_counter
```

目标是：

```text
10-14 个 archetype
30 个 deck variant
12-16 套视觉身份
```

---

## 七、大地图敌人 archetype

### 1. 普通敌人池

| archetype | 定位 | 检查点 |
|---|---|---|
| coastal_raider_blade | 快刀近身 | 控距、防守 |
| coastal_raider_spear | 粗枪压线 | 进身、破枪 |
| militia_spearman | 稳定长兵 | 距离 2-3 博弈 |
| shield_blademan | 防守反击 | 破防、别贪刀 |
| scout_footwork | 身法骚扰 | 命中距离、追击 |
| firearm_runner | 远距蓄力 | 快速进身 |
| hungry_garrison | 高势低血 | 削势、留手、军门叙事 |
| corrupt_patrolman | 官兵混战 | 旧案线索、名声风险 |

每个普通 archetype 做 2-3 个变体：

```text
basic
advanced
story_variant / aggressive_variant / defensive_variant
```

### 2. 精英敌人池

| archetype | 定位 | 检查点 |
|---|---|---|
| elite_spear_instructor | 长枪控线 | 是否理解距离优势 |
| elite_blade_counter | 刀法防反 | 是否乱出攻击 |
| elite_dual_blade_raider | 高频连段 | 是否会管势 |
| elite_firearm_guard | 远程压迫 | 是否会进身 |
| elite_military_officer | 混合机制 | Boss 前综合预演 |

每个精英 archetype 至少 2 个 deck variant：

```text
elite_basic
elite_advanced
```

---

## 八、经营节点比例

### 1. 大地图经过节点

大地图实际经过节点建议：

```text
战斗节点：14-16 个
经营 / 事件 / 修行节点：7-10 个
总经过节点：22-26 个
经营占比：30%-40%
```

默认配置：

```text
战斗节点：15
经营节点：8
总节点：23
经营占比：34.8%
```

即：

```text
战斗 : 经营 ≈ 2 : 1
```

### 2. 经营节点分类

| 节点 | 功能 | 主要影响 |
|---|---|---|
| 校场 | 升级牌、移除牌、修行 | 卡组稳定性 |
| 行营 | 回复、补给、士气 | 生存资源 |
| 军门 | 军功、上报、官场选择 | 军功 / 风险 |
| 器械所 | 武器强化、换武器 | 武器成长 |
| 师门 | 师父传承、旧招补全 | 武道 / 特殊招式 |
| 市井 | 流言、买卖、民心 | 清望 / 资源 |
| 旧案 | 线索、证物、分支 | 真结局条件 |
| 身法奇遇 | 轻功突破 | 稀缺能力 |
| 休整 | 回复、整理卡组 | 稳定性 |

### 3. 经营节点代价规则

经营节点不能是无脑正收益。

```text
给成长，就牺牲资源。
给线索，就增加风险。
给治疗，就减少战斗收益。
给军功，就可能损清望。
给清望，就可能损军门信任。
给轻功突破，就必须极稀缺且有路线代价。
```

---

## 九、武道十境成长

### 1. 成长资源

使用隐藏累计值：

```yaml
martial_xp: 武道悟性
```

不要按“打一场升一级”。

### 2. 武道十境阈值

| 境界 | 累计 martial_xp |
|---|---:|
| 第 1 境 | 0 |
| 第 2 境 | 8 |
| 第 3 境 | 18 |
| 第 4 境 | 30 |
| 第 5 境 | 44 |
| 第 6 境 | 60 |
| 第 7 境 | 78 |
| 第 8 境 | 98 |
| 第 9 境 | 120 |
| 第 10 境 | 145 |

### 3. 战斗收益

| 战斗类型 | martial_xp |
|---|---:|
| 序章战 | 3 |
| 武举兵器试 | 5 |
| 武举正式试 | 5-8 |
| 大地图普通战 | 5 |
| 大地图精英战 | 12 |
| 普通结局 Boss | 12 |
| 真结局 Boss 1 | 12 |
| 真 Boss | 16 |
| 武状元考试战 | 8-12 |

---

## 十、武道成长曲线测算

### 1. 前置固定收益

| 阶段 | martial_xp |
|---|---:|
| 序章 | 3 |
| 武举兵器试 2 场 | 10 |
| 武举正式试 3 场 | 19 |
| **进入大地图前合计** | **32** |

进入大地图前：

```text
武道约第 4 境
```

### 2. 普通路线

```text
大地图普通战 12 场
大地图精英战 3 场
普通结局 Boss 1 场
```

收益：

```text
前置 32
普通战 12 × 5 = 60
精英战 3 × 12 = 36
普通 Boss 12
总计 = 140
```

结果：

```text
最终第 9 境附近
部分保守路线可能第 8 境
可以通普通结局
```

### 3. 标准路线

```text
大地图普通战 11 场
大地图精英战 4 场
Boss 1 场
```

收益：

```text
前置 32
普通战 11 × 5 = 55
精英战 4 × 12 = 48
Boss 12
总计 = 147
```

结果：

```text
第 10 境
可以进入真结局压力区
```

### 4. 精英路线

```text
大地图普通战 10 场
大地图精英战 5 场
```

收益：

```text
前置 32
普通战 10 × 5 = 50
精英战 5 × 12 = 60
大地图结束 = 142
```

如果再通过真结局 Boss 1 或武状元资格战：

```text
142 + 12 = 154
稳定第 10 境
```

结果：

```text
精英路线稳定十境
可挑战真 Boss
可触发武状元路线资格判断
```

---

## 十一、第 10 境奖励

第 10 境必须有明确数值收益。

建议：

```yaml
realm_10_bonus:
  damage_multiplier: 1.10
  break_momentum_multiplier: 1.10
  max_momentum_bonus: 1
  starting_momentum_bonus: 1
  boss_dialogue_unlock: true
  true_ending_eligibility_bonus: true
  wuzhuangyuan_route_eligibility: true
```

原则：

```text
第 10 境不是普通结局门槛。
第 10 境是真 Boss 与武状元路线的强度基准。
第 10 境要让玩家明显感觉破境后能打。
```

---

## 十二、轻功成长规则

### 1. 核心定位

轻功不是十境系统。

轻功是最高 4 阶的极度稀缺横向资源。

```text
轻功上限：4
玩家正常只能到 2
奇遇下可以到 4
轻功不是战斗打多了自然上涨
轻功不是普通通关必要条件
```

### 2. 轻功等级

| 轻功等级 | 定位 | 获取难度 |
|---|---|---|
| 0 | 常人步法 | 初始 |
| 1 | 身法入门 | 武举 / 基础修行可得 |
| 2 | 江湖可用 | 正常路线最高 |
| 3 | 奇遇身法 | 稀有奇遇 / 师门 / 旧案隐藏 |
| 4 | 轻功圆满 | 极稀缺奇遇，可作为武状元 / 真结局高阶优势 |

### 3. 正常上限

正常路线最多：

```text
轻功 2
```

规则：

```text
单靠战斗胜利不能超过 2。
单靠武举线不能超过 2。
单靠普通经营节点不能超过 2。
没有奇遇标记不能超过 2。
```

### 4. 轻功突破方式

轻功不建议使用普通经验表，而使用“阶位 + 突破标记”。

```yaml
normal_lightness_cap: 2
lightness_cap_unlock_3: rare_encounter
lightness_cap_unlock_4: rare_encounter_chain
```

### 5. 轻功来源

| 来源 | 可到达 | 说明 |
|---|---:|---|
| 武举步法试 | 1 | 教学性提升 |
| 普通身法节点 | 1-2 | 正常成长 |
| 战斗中步法表现 | 1-2 | 辅助到正常上限 |
| 师门暗授 | 2-3 | 稀有 |
| 江湖奇遇 | 3-4 | 主要突破来源 |
| 旧案隐藏追击 | 3 | 真结局相关 |
| 武状元路线特殊考核 | 3-4 | 高阶表现奖励 |
| 普通战斗胜利 | 不直接提升 | 最多给 practice 标记 |

### 6. 轻功 3

轻功 3 需要：

```yaml
lightness_3_unlock:
  current_lightness: 2
  required_event:
    any:
      - lightness_master_encounter
      - master_hidden_teaching
      - old_case_secret_pursuit
      - high_clean_reputation_wuxia_reward
      - wuzhuangyuan_footwork_trial_bonus
```

### 7. 轻功 4

轻功 4 是极度稀缺结果。

推荐：

```yaml
lightness_4_unlock:
  current_lightness: 3
  required:
    one_of:
      - rare_lightness_encounter_chain
      - master_final_teaching
      - wuzhuangyuan_final_trial_bonus
      - true_route_hidden_pursuit_success
```

注意：

```text
轻功 4 可以来自奇遇。
轻功 4 不要求所有真结局玩家都拿到。
轻功 4 不应作为普通 Boss 或真 Boss 硬门槛。
```

### 8. 轻功战斗收益

轻功优势主要体现在：

| 等级 | 战斗表现 |
|---|---|
| 1 | 少量位移优势，部分身法牌更稳定 |
| 2 | 正常构筑可用，能处理远距 / 追击压力 |
| 3 | 起手距离、闪避、追击事件明显变强 |
| 4 | 特殊身法优势，Boss / 武状元考试中有额外表现 |

轻功 4 建议效果：

```yaml
lightness_4_bonus:
  opening_distance_choice: true
  first_turn_mobility_bonus: true
  evade_once_per_battle: true
  pursuit_event_bonus: high
  wuzhuangyuan_exam_bonus: true
```

不建议给直接攻击倍率。

轻功的收益应该是：

```text
起手距离
闪避窗口
追击能力
撤离能力
特殊选项
考试表现
结局文本
```

---

## 十三、Boss 与结局路线

### 1. 普通结局

| 项目 | 规则 |
|---|---|
| Boss 数量 | 1 |
| 玩家目标境界 | 8-9 |
| 轻功需求 | 1-2 |
| 是否要求十境 | 否 |
| 是否要求轻功 3-4 | 否 |
| 结局性质 | 普通收束，旧案未完全揭开或只局部揭开 |

普通 Boss 设计目标：

```text
第 8 境：能通，但吃力。
第 9 境：标准体验。
第 10 境：明显压制。
```

### 2. 真结局

| 项目 | 规则 |
|---|---|
| Boss 数量 | 2 |
| Boss 1 | 旧案守门人 / 军门强敌 |
| 真 Boss | 按第 10 境强度设计 |
| 玩家目标境界 | 第 10 境 |
| 轻功需求 | 2-3 更舒服，但不硬性要求 4 |
| 结局性质 | 旧案真相收束 |

真 Boss 设计目标：

```text
第 9 境：极难，不推荐。
第 10 境：标准挑战。
第 10 境 + 成型构筑：合理通关。
轻功 4：提供额外优势和特殊表现，不作为硬门槛。
```

### 3. 武状元特殊结局

武状元路线是独立特殊结局，不是普通 Boss 或真 Boss 的附属。

触发后进入：

```text
回京考试
5 场战斗
走完获得武状元特殊结局
```

它的主题不是旧案真相，而是：

```text
军功、武境、制度认可、从海防战场回到京城考场
```

---

## 十四、武状元路线

### 1. 触发条件

大地图后段出现特殊条件判断。

暂定核心条件：

```yaml
wuzhuangyuan_route_unlock:
  required:
    - martial_realm: 10
    - military_merit: high
  optional_bonus:
    - lightness_level: 3_or_4
    - weapon_mastery: high
    - elite_battle_count: 4_or_more
    - clean_reputation_not_too_low
```

最小触发条件：

```text
武境 10
军功高
```

推荐不要只要武境 10，因为那会和真结局路线混在一起。

武状元路线必须强调：

```text
你不只是武艺高，还被军门制度承认，有资格回京应试。
```

### 2. 触发时机

触发点建议在大地图后段：

```text
M12-M15 后
Boss 前整备节点
军门节点
战后上报节点
```

触发后给玩家分支：

```text
继续追旧案 → 真结局路线
奉调回京 → 武状元路线
稳妥收束 → 普通结局
```

### 3. 路线性质

武状元路线不应和真结局完全重叠。

| 路线 | 主题 |
|---|---|
| 普通结局 | 海防事件局部收束 |
| 真结局 | 旧案真相与幕后压迫 |
| 武状元结局 | 战功入制，武艺被朝廷承认 |

武状元路线可以保留旧案未尽之感：

```text
你赢了考试，但未必赢了旧案。
```

这样它不是“最好结局”，而是“特殊制度结局”。

---

## 十五、武状元路线 5 场战斗设计

### 1. 总结构

| 战斗 | 名称 | 主题 | 检查点 |
|---|---|---|---|
| WZ01 | 入京校阅 | 基础兵器复核 | 检查主武器基础循环 |
| WZ02 | 步战较艺 | 距离 / 步法 | 检查控距、轻功、位移 |
| WZ03 | 马步兵械 | 多武器应对 | 检查泛用卡组与武器理解 |
| WZ04 | 擂台连胜 | 连续对人战 | 检查资源管理与稳定性 |
| WZ05 | 殿前终试 | 武状元终战 | 检查十境强度与完整构筑 |

### 2. WZ01 入京校阅

定位：

```text
资格复核战，不应过难。
```

敌人：

```text
capital_examiner_basic
```

检查：

- 玩家是否到达 10 境后仍有基础循环
- 主武器牌是否成型
- 不考复杂机制

推荐奖励：

```yaml
martial_xp: 8
weapon_xp: 3
lightness_reward_type: none
```

### 3. WZ02 步战较艺

定位：

```text
步法、距离、身法考试。
```

敌人：

```text
capital_footwork_examiner
```

检查：

- 距离控制
- 位移牌使用
- 远近转换
- 轻功等级带来的特殊优势

轻功 3-4 在这里有明显优势，但轻功 2 也能通过。

推荐奖励：

```yaml
martial_xp: 8
weapon_xp: 2
lightness_reward_type: rare_breakthrough_possible
lightness_cap_unlock: cap_3_or_cap_4_if_rare_condition_met
```

### 4. WZ03 马步兵械

这里不一定真的做骑战系统，可以抽象成“马步兵械试”。

定位：

```text
测试玩家面对不同兵器与距离变化的适应能力。
```

敌人：

```text
capital_mixed_weapon_examiner
```

检查：

- 对长兵、短兵、远距压迫的综合应对
- 通用牌是否足够
- 武器限定牌是否不是单一套路

推荐奖励：

```yaml
martial_xp: 9
weapon_xp: 4
card_reward_pool: exam_signature_or_generic_rare
```

### 5. WZ04 擂台连胜

定位：

```text
连续战压力测试。
```

可以做成一场战斗内多阶段，也可以做成单独一场高压战。

敌人：

```text
capital_duel_chain_elite
```

检查：

- 势管理
- 防守
- 回复
- 卡组厚度
- 连招稳定性
- 是否依赖单一爆发

推荐奖励：

```yaml
martial_xp: 10
weapon_xp: 4
resource_reward: none_or_low
```

这里要有消耗感，不要让玩家越考越满。

### 6. WZ05 殿前终试

定位：

```text
武状元终战。
```

敌人：

```text
imperial_final_examiner
```

强度基准：

```text
武道 10
主武器构筑成型
轻功 2 可打
轻功 3-4 有明显优势
```

推荐奖励：

```yaml
martial_xp: 12
weapon_xp: 5
ending: wuzhuangyuan_special_ending
title_unlock: 武状元
```

WZ05 不一定比真 Boss 更邪门，但应更“正统”。

真 Boss 是生死与旧案。  
武状元终试是制度、武艺、声名。

---

## 十六、武状元路线卡组需求

武状元路线需要 5 个专用 deck。

| deck_id | 定位 |
|---|---|
| exam_capital_basic_weapon | 基础兵器复核 |
| exam_capital_footwork | 步法距离考核 |
| exam_capital_mixed_weapon | 多武器应对 |
| exam_capital_duel_chain | 连续对人压力 |
| exam_imperial_final_examiner | 殿前终试 |

这些 deck 可以复用大地图精英卡牌，但要有京城考试特征：

```text
更规整
更克制
更少亡命招
更重破绽惩罚
更像制度化武艺
```

---

## 十七、路线分流逻辑

大地图后段进入结局判断。

### 1. 普通结局判断

条件：

```yaml
normal_ending:
  default: true
  conditions:
    - true_route_unlocked: false
    - wuzhuangyuan_route_unlocked: false
```

玩家状态：

```text
武道 8-9
军功中低或普通
旧案推进不足
轻功 1-2
```

### 2. 真结局判断

条件示例：

```yaml
true_ending_unlock:
  required:
    - old_case_progress: high
  recommended:
    - martial_realm: 9_or_10
    - key_evidence_count: enough
    - clean_reputation_or_military_merit: route_matched
```

玩家状态：

```text
武道 9-10
旧案推进高
关键证据足够
愿意继续追旧案
```

### 3. 武状元路线判断

条件：

```yaml
wuzhuangyuan_route_unlock:
  required:
    - martial_realm: 10
    - military_merit: high
  recommended:
    - elite_battle_count: 4_or_more
    - weapon_mastery: high
```

玩家状态：

```text
武道 10
军功高
大地图精英路线或高压路线
被军门举荐回京应试
```

### 4. 多路线同时满足时

如果同时满足真结局和武状元路线，不自动替玩家决定。

给选择：

```text
追旧案
回京应试
奉命收束
```

选择对应：

| 选择 | 进入 |
|---|---|
| 追旧案 | 真结局 |
| 回京应试 | 武状元特殊结局 |
| 奉命收束 | 普通结局 / 高评价普通结局 |

---

## 十八、战斗与经营混排规则

### 1. 连续战斗限制

```text
连续普通战斗最多 3 场。
连续含精英战斗最多 2 场。
精英战后必须出现经营 / 休整 / 奖励节点候选。
Boss 前必须出现整备节点。
武状元路线开始前必须出现“回京整备”节点。
```

### 2. 每 5 场战斗必须给一次构筑调整机会

| 区间 | 必须出现 |
|---|---|
| M01-M05 | 至少 1 次卡牌获得 / 升级 |
| M06-M10 | 至少 1 次武器 / 修行 / 移除牌 |
| M11-M15 | 至少 1 次 Boss / 结局路线前定向强化 |
| WZ01-WZ05 | 至少 1 次考试间整备，但不能完全回血重置 |

### 3. 武状元路线资源规则

武状元路线是高阶考试，不是免费奖励关。

```text
进入武状元线后，不再大量发新机制。
主要检查已有构筑。
允许少量整备，但不能每场满血满资源。
WZ04-WZ05 应形成连续压力。
```

---

## 十九、battle slot 标准字段

每个战斗节点建议使用统一字段。

```yaml
battle_slot_id:
stage:
battle_index:
battle_type: tutorial / weapon_trial / exam / normal / elite / boss / wuzhuangyuan_exam
route_type: common / true_route / wuzhuangyuan / optional
enemy_archetype:
enemy_deck_id:
deck_tier: basic / advanced / elite / boss / exam
expected_player_realm:
expected_lightness_level:
martial_xp_reward:
weapon_xp_reward:
lightness_reward_type: none / practice / level_up / cap_unlock / rare_breakthrough
lightness_reward_flag:
lightness_cap_unlock: none / cap_2 / cap_3 / cap_4
card_reward_pool:
operation_reward:
military_merit_reward:
narrative_tags:
old_case_tags:
resource_risk:
ending_route:
can_trigger_realm_10:
can_trigger_lightness_breakthrough:
can_trigger_wuzhuangyuan_route:
can_repeat_reward: false
```

武状元示例：

```yaml
battle_slot_id: wz05_imperial_final_examiner
stage: wuzhuangyuan_route
battle_index: WZ05
battle_type: wuzhuangyuan_exam
route_type: wuzhuangyuan
enemy_archetype: imperial_final_examiner
enemy_deck_id: exam_imperial_final_examiner
deck_tier: exam
expected_player_realm: 10
expected_lightness_level: 2
martial_xp_reward: 12
weapon_xp_reward: 5
lightness_reward_type: rare_breakthrough
lightness_reward_flag: imperial_footwork_recognition
lightness_cap_unlock: cap_4
card_reward_pool: none_or_title_reward
operation_reward: wuzhuangyuan_title
military_merit_reward: high
narrative_tags:
  - capital_exam
  - imperial_recognition
  - military_merit
old_case_tags: []
resource_risk: high
ending_route: wuzhuangyuan
can_trigger_realm_10: false
can_trigger_lightness_breakthrough: true
can_trigger_wuzhuangyuan_route: false
can_repeat_reward: false
```

---

## 二十、制作数量反推

### 1. battle slot / deck variant 数量

| 类型 | 实际体验 | 候选 / 制作 |
|---|---:|---:|
| 序章 | 1 | 1 |
| 武举线 | 5 | 5 |
| 大地图普通战 | 10-12 | 20-24 |
| 大地图精英战 | 3-5 | 8-10 |
| 普通 Boss | 1 | 1 |
| 真结局 Boss | 2 | 2 |
| 武状元考试 | 5 | 5 |
| **普通结局实际体验** | **约 22** |  |
| **真结局实际体验** | **约 23** |  |
| **武状元结局实际体验** | **约 26** |  |
| **总候选制作规模** |  | **42-48 个 battle slot / deck variant** |

### 2. deck 数量

| 类型 | deck 数 |
|---|---:|
| 教学 / 武举 deck | 6 |
| 大地图普通 deck | 20-24 |
| 大地图精英 deck | 8-10 |
| Boss deck | 3-5 |
| 武状元考试 deck | 5 |
| **正式可重复版合计** | **42-50** |

可运行最小版：

```text
教学 / 武举：6
大地图普通：12
大地图精英：6
Boss：3
武状元考试：5
合计：32 个 deck
```

正式可重复版：

```text
教学 / 武举：6
大地图普通：20-24
大地图精英：8-10
Boss：3-5
武状元考试：5
合计：42-50 个 deck
```

### 3. 美术身份数量

| 类型 | 建议数量 |
|---|---:|
| 教学 / 武举敌人 | 4-5 |
| 大地图普通敌人视觉身份 | 8-10 |
| 大地图精英敌人视觉身份 | 4-5 |
| Boss | 2-3 |
| 武状元考试敌人 | 3-5 |
| **合计** | **21-28** |

武状元考试敌人可以复用“京营武官 / 教头 / 殿前考官”视觉体系，重点靠卡组区分。

---

## 二十一、最终路线一览

### 1. 普通结局路线

```text
序章 1
武举 5
大地图约 15
普通 Boss 1
总计约 22 战
```

结果：

```text
武道：8-9
轻功：1-2
结局：普通结局
```

### 2. 真结局路线

```text
序章 1
武举 5
大地图约 15
真结局 Boss 2
总计约 23 战
```

结果：

```text
武道：9-10，推荐 10
轻功：2-3，轻功 4 是额外优势
结局：真结局
```

### 3. 武状元特殊结局路线

```text
序章 1
武举 5
大地图约 15
回京考试 5
总计约 26 战
```

触发：

```text
武境 10
军功高
大地图后段触发举荐 / 回京考试
```

结果：

```text
武道：10
轻功：2 正常可打，3-4 有优势
结局：武状元特殊结局
```

---

## 二十二、验收标准

这版方案验收时，必须满足：

1. 序章固定 1 战。
2. 武举线固定 5 战，其中兵器使用 2 战包含在武举线内。
3. 大地图实际战斗约 15 场，可浮动 14-16。
4. 大地图敌人 / 卡组候选池约 30 个，是实际体验数量 2 倍左右。
5. 大地图经营节点占 30%-40%。
6. 普通路线最终 8-9 境，可通普通 Boss。
7. 精英路线稳定 10 境。
8. 普通结局 1 个 Boss。
9. 真结局 2 个 Boss，真 Boss 按 10 境强度设计。
10. 轻功上限 4，正常只能到 2，奇遇下可以到 4。
11. 轻功 4 是极度稀缺优势，不是普通或真 Boss 硬门槛。
12. 大地图满足武境 10、军功高等特殊条件后，可触发武状元路线。
13. 武状元路线为回京考试 5 战，走完获得武状元特殊结局。
14. 若真结局和武状元路线同时满足，应该给玩家选择，而不是自动替玩家决定。

---

## 二十三、一句话定版

> 本局基础流程由序章 1 战、武举线 5 战、大地图约 15 战构成。普通结局追加 1 个 Boss，总计约 22 战，支持 8-9 境通关；真结局追加 2 个 Boss，总计约 23 战，真 Boss 按 10 境设计；若大地图后段满足武境 10、军功高等特殊条件，则触发回京武状元路线，追加 5 场考试战，总计约 26 战，获得武状元特殊结局。轻功改为最高 4 阶的极度稀缺资源，正常路线只能到 2，奇遇下可以突破到 4，主要提供位移、闪避、追击、考试表现和特殊文本优势。
