# 《大明之沧海嘀鸣》MVP 单局美术完整度推进方案

> 目标：把“行军图一：初出山”推进到可完整体验的一局美术闭环。  
> 范围：序章、肉鸽地图、6 类节点、Boss、军门压案、结局反馈。  
> 不做：不扩大战斗规则、不做完整人生线、不做多地图、不做全角色动画包、不重构 Web 外壳。

---

## 0. 当前美术推进判断

当前已经有三类文档基础：

```text
MVP_NARRATIVE_SCRIPT.md：单局叙事脚本
CHARACTER_IMAGE_PROMPTS_STORY.md：剧情角色美术提示词
SCENE_IMAGE_PROMPTS_STORY.md：剧情场景美术提示词
```

下一步不是继续写更多世界观，而是把单局体验需要的美术资产分级补齐：

```text
一局能开始
一局能走地图
一局能看懂节点类型
一局能看到关键旧案碎片
一局能打到 Boss
一局能看到军门压案与结局分支
```

---

## 1. 单局美术完整度目标

### 1.1 S 级目标：叙事闭环成立

玩家即使只玩一局，也必须从画面上看懂：

```text
十年前村子被烧；
主角被师父救下；
十年后主角出山；
敌人不是普通海盗；
倭寇手里有明制火器；
失踪军械与军门有关；
Boss 被暗箭灭口；
证据摆上军门案头后被压下。
```

### 1.2 A 级目标：节点类型可识别

玩家进入地图后，必须一眼区分：

```text
普通战斗
精英战斗
事件
营地
旧物
Boss
```

### 1.3 B 级目标：角色关系可感知

玩家不读长文，也能从图上感知：

```text
主角：年轻武官，长枪，压着旧恨；
师父：沉默老兵，旧腰刀，藏着旧案；
海商：文明危险，无战斗武器；
押运官：恐惧疲惫，知道失械案；
兵变营头：悲剧敌人，不是怪物；
倭寇首领：表层敌人，身上有明制火器疑点。
```

---

## 2. 美术资产分级清单

## 2.1 P0 必须资产：没有就不成局

### P0-1 序章关键图 3 张

| 编号 | 资产 | 文件建议 | 用途 | 验收重点 |
|---|---|---|---|---|
| P0-S01 | 火从海边来 | `prologue_burning_village.png` | 序章开场 | 退潮、远村火、压抑，不血腥 |
| P0-S02 | 师父挡刀 | `prologue_master_blocks_blade.png` | 序章救场 | 旧腰刀挡倭刀，童年主角在地上 |
| P0-S03 | 十年后出山 | `prologue_ten_years_later.png` | 序章转场 | 主角长枪，师父磨旧刀 |

### P0-2 单局核心背景 5 张

| 编号 | 资产 | 文件建议 | 节点 | 验收重点 |
|---|---|---|---|---|
| P0-B01 | 军令巡海 | `node_military_order.png` | 起点 | 军令、湿旗、军门压迫 |
| P0-B02 | 海边伏击 | `node_beach_ambush.png` | 普通战斗 | 整齐脚印，敌人有军伍感 |
| P0-B03 | 明制火器 | `node_ming_firearms.png` | 旧物 | 官造火铳、火器箱、潮湿船舱 |
| P0-B04 | Boss 破船 | `boss_wakou_wrecked_ship.png` | Boss | 破船、火器箱、倭寇首领舞台 |
| P0-B05 | 军门压案 | `ending_military_office_coverup.png` | 结尾 | 证据上案，师父门外，冷雨 |

### P0-3 关键角色立绘 5 张

| 编号 | 角色 | 文件建议 | 用途 | 验收重点 |
|---|---|---|---|---|
| P0-C01 | 主角年轻武官 | `protagonist_young.png` | 全局主角 | 长枪明确，年轻但压抑 |
| P0-C02 | 主角童年 | `protagonist_child.png` | 序章 | 无武器，布片/祖牌，恐惧失声 |
| P0-C03 | 师父沉默老兵 | `mentor_veteran.png` | 序章/营地 | 旧腰刀，疲惫沉默 |
| P0-C04 | 小股倭寇首领 | `wakou_leader.png` | Boss | 海寇弯刀 + 明制火铳 |
| P0-C05 | 军门上官 | `military_superior.png` | 军令/压案 | 制度脸，冷，不奸笑 |

### P0-4 UI / 地图节点图标 6 枚

| 编号 | 图标 | 文件建议 | 验收重点 |
|---|---|---|---|
| P0-I01 | 普通战斗 | `icon_node_battle.png` | 兵刃交错，普通危险 |
| P0-I02 | 精英战斗 | `icon_node_elite.png` | 旗、血锈、强敌压迫 |
| P0-I03 | 事件 | `icon_node_event.png` | 信纸/灯/问号感，但不现代 |
| P0-I04 | 营地 | `icon_node_camp.png` | 营火、帐、休整 |
| P0-I05 | 旧物 | `icon_node_relic.png` | 旧物碎片、证据感 |
| P0-I06 | Boss | `icon_node_boss.png` | 破船/海寇旗/强压迫 |

---

## 2.2 P1 强化资产：让一局更完整

### P1-1 节点背景补齐

| 编号 | 资产 | 文件建议 | 节点 |
|---|---|---|---|
| P1-B01 | 渔村残火 | `node_burnt_fishing_village.png` | 普通战斗 |
| P1-B02 | 押运官空车 | `node_transport_empty_cart.png` | 精英战斗 |
| P1-B03 | 欠饷营 | `node_mutiny_camp.png` | 精英战斗 |
| P1-B04 | 海商宴 | `node_merchant_banquet.png` | 事件 |
| P1-B05 | 夜半磨刀 | `node_night_sharpening.png` | 营地 |
| P1-B06 | 军门信使 | `node_military_messenger.png` | 事件 |

### P1-2 角色立绘补齐

| 编号 | 角色 | 文件建议 | 用途 |
|---|---|---|---|
| P1-C01 | 海商豪强 | `merchant_magnate.png` | 海商宴 |
| P1-C02 | 失械案押运官 | `transport_officer.png` | 精英/事件 |
| P1-C03 | 兵变营头 | `mutiny_captain.png` | 精英 |
| P1-C04 | 敌方枪手 | `enemy_spearman_story.png` | 普通战斗叙事图 |
| P1-C05 | 敌方刀客 | `enemy_blademaster_story.png` | 普通战斗叙事图 |

### P1-3 旧物插画 4 张

| 编号 | 旧物 | 文件建议 | 叙事功能 |
|---|---|---|---|
| P1-R01 | 官造火铳 | `relic_ming_firearm.png` | 明制火器证据 |
| P1-R02 | 涂改军报 | `relic_altered_report.png` | 功名线 / 压案 |
| P1-R03 | 旧枪缨 | `relic_old_spear_tassel.png` | 师父旧部 |
| P1-R04 | 火器押运牌 | `relic_transport_token.png` | Boss 掉落 / 旧案闭环 |

---

## 2.3 P2 氛围资产：提升质感但可后置

| 编号 | 资产 | 文件建议 | 用途 |
|---|---|---|---|
| P2-A01 | 上报结局图 | `ending_report_truth.png` | 结局分支 |
| P2-A02 | 掩盖结局图 | `ending_cover_case.png` | 结局分支 |
| P2-A03 | 私查结局图 | `ending_secret_investigation.png` | 结局分支 |
| P2-A04 | 借势结局图 | `ending_trade_for_power.png` | 结局分支 |
| P2-A05 | 暗箭灭口复现 | `boss_arrow_silence.png` | Boss 后演出 |
| P2-A06 | 地图背景底图 | `map_march_coast.png` | 肉鸽地图 |

---

## 3. 单局视觉流程

## 3.1 序章视觉流程

```text
黑屏潮声
→ prologue_burning_village.png
→ 父亲/敌人黑屏对白
→ 童年主角木刀无效
→ prologue_master_blocks_blade.png
→ 敌人“军……”
→ 暗箭灭口
→ prologue_ten_years_later.png
→ 行军图一：初出山
```

### 最低实现

```text
用 3 张 P0 序章图 + 黑屏字幕即可成立。
```

### 完整实现

```text
增加父亲门影、木刀无效、暗箭灭口 3 张过场图。
```

---

## 3.2 肉鸽地图视觉流程

```text
地图底图：map_march_coast.png
节点图标：6 类图标
节点标题：军令 / 海边伏击 / 明制火器 / 海商宴 / 押运官 / Boss
节点进入后：展示节点背景图 + 旁白 + 对白 + 选择
```

### 地图底图要求

```text
沿海行军图；
不是现代地图；
像军务路线图和水墨海岸结合；
有潮线、山道、渔村、军门、破船位置；
节点以旗牌、火点、旧物标记呈现。
```

---

## 3.3 节点视觉流程

每个节点统一结构：

```text
背景图
→ 节点标题
→ 一句旁白
→ 人物立绘或旧物图
→ 1-3 句对白
→ 2-3 个选择
→ 变量变化反馈
```

### 示例：明制火器

```text
背景：node_ming_firearms.png
旧物图：relic_ming_firearm.png
旁白：火器保养得很好。甚至比卫所库里的还好。
选择：上交军门 / 私下留证 / 毁掉
变量：军功 / 旧案线索 / 清望
```

---

## 3.4 Boss 视觉流程

```text
boss_wakou_wrecked_ship.png
→ wakou_leader.png
→ 战斗
→ Boss 低血量对白：“你找错海了。”
→ 击败后：“穿的可不是倭甲。”
→ boss_arrow_silence.png
→ 掉落 relic_transport_token.png
```

---

## 3.5 结尾视觉流程

```text
ending_military_office_coverup.png
→ 军门上官立绘
→ 案上证据：火器箱 / 押运牌 / 涂改军报
→ 四选一：上报 / 掩盖 / 私查 / 借势
→ 对应结局图或文字结算
```

---

## 4. 资产目录建议

沿用当前项目目录，不新增复杂结构。

```text
assets/pixel_battle/backgrounds/
  prologue_burning_village.png
  prologue_master_blocks_blade.png
  prologue_ten_years_later.png
  node_military_order.png
  node_beach_ambush.png
  node_burnt_fishing_village.png
  node_transport_empty_cart.png
  node_mutiny_camp.png
  node_merchant_banquet.png
  node_military_messenger.png
  node_night_sharpening.png
  node_ming_firearms.png
  boss_wakou_wrecked_ship.png
  ending_military_office_coverup.png
  ending_report_truth.png
  ending_cover_case.png
  ending_secret_investigation.png
  ending_trade_for_power.png

assets/pixel_battle/portraits/
  protagonist_young.png
  protagonist_child.png
  mentor_veteran.png
  wakou_leader.png
  military_superior.png
  merchant_magnate.png
  transport_officer.png
  mutiny_captain.png
  enemy_spearman_story.png
  enemy_blademaster_story.png

assets/pixel_battle/ui/
  icon_node_battle.png
  icon_node_elite.png
  icon_node_event.png
  icon_node_camp.png
  icon_node_relic.png
  icon_node_boss.png

assets/pixel_battle/relics/
  relic_ming_firearm.png
  relic_altered_report.png
  relic_old_spear_tassel.png
  relic_transport_token.png
```

注意：如果不想新增 `relics/` 目录，也可以先放入：

```text
assets/pixel_battle/ui/relic_*.png
```

---

## 5. 生成顺序建议

### 第 1 轮：先保证一局能闭环

```text
1. prologue_burning_village.png
2. prologue_master_blocks_blade.png
3. prologue_ten_years_later.png
4. protagonist_young.png
5. protagonist_child.png
6. mentor_veteran.png
7. node_military_order.png
8. node_beach_ambush.png
9. node_ming_firearms.png
10. boss_wakou_wrecked_ship.png
11. wakou_leader.png
12. ending_military_office_coverup.png
13. military_superior.png
14. 6 类节点图标
```

### 第 2 轮：补齐节点质感

```text
1. node_burnt_fishing_village.png
2. node_transport_empty_cart.png
3. node_mutiny_camp.png
4. node_merchant_banquet.png
5. node_night_sharpening.png
6. merchant_magnate.png
7. transport_officer.png
8. mutiny_captain.png
9. relic_ming_firearm.png
10. relic_altered_report.png
11. relic_old_spear_tassel.png
12. relic_transport_token.png
```

### 第 3 轮：补结局与演出

```text
1. boss_arrow_silence.png
2. ending_report_truth.png
3. ending_cover_case.png
4. ending_secret_investigation.png
5. ending_trade_for_power.png
6. map_march_coast.png
```

---

## 6. 单张资产验收标准

### 6.1 背景图验收

```text
[ ] 一眼看出节点地点
[ ] 能承载旁白情绪
[ ] 没有现代元素
[ ] 色调低饱和，不抢 UI
[ ] 关键叙事物件清楚：火器、军报、旧枪缨、火器箱、军令
[ ] 不靠大段文字解释
```

### 6.2 角色立绘验收

```text
[ ] 武器 / 道具严格符合锁定设定
[ ] 人物气质符合脚本定位
[ ] 不过度玄幻化
[ ] 不可爱化
[ ] 剪影清楚
[ ] 可用于剧情对话框
```

### 6.3 旧物图验收

```text
[ ] 单图能看懂是什么物件
[ ] 物件带有旧案感
[ ] 不要画成现代文物展品
[ ] 可在 UI 中缩小显示仍可识别
[ ] 与节点旁白强绑定
```

### 6.4 节点图标验收

```text
[ ] 六类节点差异明显
[ ] 暗色金边或旧铜风格统一
[ ] 小尺寸下可识别
[ ] 不与卡牌图标混淆
[ ] 不用现代 UI 风格
```

---

## 7. Web 接入优先级

### 7.1 优先接背景图

先把节点背景图放进现有 UI 容器或节点详情面板，不要重构 Web 外壳。

```text
起点 / 普通战斗 / 旧物 / Boss / 结尾
```

### 7.2 再接人物立绘

人物立绘作为节点事件层叠图或对话头像，不影响战斗 actor runtime。

```text
主角、师父、海商、押运官、兵变营头、倭寇首领、军门上官
```

### 7.3 最后接节点图标

节点图标用于肉鸽地图 UI。若地图系统未完成，可先作为占位 UI 使用。

---

## 8. 不动范围

```text
不重构 web_shell.html；
不重构底部响应式 UI；
不改战斗规则；
不替换 actor runtime；
不强行把剧情立绘塞进 battle actor sheet；
不把剧情美术和战斗 sprite 混用。
```

---

## 9. 交付验收：单局美术完整度评分

### C 级：能跑但不完整

```text
有主角、师父、Boss；
有 3 张序章图；
有 Boss 和军门压案图；
但节点大量复用背景。
```

### B 级：一局闭环成立

```text
P0 资产全部完成；
6 类节点图标完成；
玩家能从画面理解旧案线。
```

### A 级：节点体验完整

```text
P0 + P1 资产完成；
每类核心节点有独立背景；
关键人物均有立绘；
旧物图能独立展示。
```

### S 级：可用于对外展示

```text
P0 + P1 + P2 资产完成；
四种结局图完成；
地图底图完成；
序章与 Boss 后灭口有独立演出图；
整体风格统一。
```

---

## 10. 当前下一刀

```text
第一刀：生成 P0 必须资产。
第二刀：把 P0 背景图接入 MVP 节点展示。
第三刀：接入 P0 人物立绘与军门压案结尾。
第四刀：补齐 P1 节点背景和旧物图。
第五刀：补 P2 结局图与地图底图。
```

一句话：

```text
先让玩家完整看完“火从海边来 → 出山 → 明制火器 → Boss 灭口 → 军门压案”的一局视觉闭环。
```
