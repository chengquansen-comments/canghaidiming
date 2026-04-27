# 《大明之沧海嘀鸣》正式美术生产路线图

> 版本：v0.1  
> 分支：`main`  
> 来源：基于《美术规划.pdf》review 后，结合当前仓库 TSV / JSON / SVG 资源状态刷新。  
> 用途：把“正式上线级美术目标”转成可执行的资源生产、挂接、验收路线。

---

## 0. 总判断

当前项目已经从“纯占位”推进到“可运行风格样张阶段”，但还不是正式美术资产阶段。

当前正确方向不是继续随机补图，而是建立稳定闭环：

```text
叙事源头 → 节点状态 → 参考图 → SVG 运行资源 → visual_path / track 挂接 → 游戏内截图验收
```

正式美术目标不是“古风漂亮图”，而是：

```text
明代海疆旧案感 + 军武压迫感 + 隐晦叙事痕迹
```

核心关键词：

```text
明代海疆
军门案卷
残火黑潮
卫所营门
倭寇暗袭
火器木匣
缺页名册
官泥封缄
忠义牺牲
风起沧海
```

---

## 1. 当前完成度复评

| 模块 | 旧评估 | 当前复评 | 判断 |
|---|---:|---:|---|
| 战斗背景 | 45% | 60% | 7 张 battle_bg 已完成一轮正式分镜级强化，可支撑 Demo 展示，但仍非宣发 key art |
| 剧情表演区 | 25% | 30% | 结构已清楚，参考图与资源池开始建立，但 performance_tracks 尚未正式挂接 |
| 角色美术 | 15% | 20% | 已有师父、倭寇、押运官等剪影资源池，但主角 / 师父 / Boss 正式半身仍缺 |
| UI 美术 | 35% | 35% | 结构正确，但案卷 / 军令 / 兵书视觉包装未开始系统落地 |
| 证据道具 | 10% | 35% | 已有火器箱、缺页案卷、无封泥信等基础 SVG；还需旧刀、火器刻印、湿名册、空木匣 |

结论：

```text
战斗场景已可看；剧情演出和证据链还没真正跑起来。
```

下一步最重要的是：

```text
把“参考图”转成“SVG 运行资源”，再通过 node_status / performance_tracks 挂到主流程节点。
```

---

## 2. 当前文件口径

美术生产必须遵守三层文件关系：

```text
剧情内容源头：
- tables/narrative_mvp_prologue_steps.tsv
- tables/narrative_mvp_nodes.tsv

节点流程 / 实装 / 美术挂接源头：
- tables/narrative_mvp_node_status.tsv

编译产物 / 游戏运行读取：
- data/narrative_mvp_nodes.json
```

执行规则：

1. 美术意象看 TSV。
2. 当前主流程优先级看 `node_status.tsv` 的 `flow_enabled=true`。
3. 节点视觉挂接优先看 `node_status.tsv.visual_path`。
4. 游戏内验收看 `data/narrative_mvp_nodes.json` 实际是否读到节点。
5. `reserved` 节点先规划，不抢 P0。

---

## 3. 正式美术三条生产线

### 3.1 运行 SVG 线

用于 Godot 实际读取。

```text
assets/pixel_battle/backgrounds/*.svg
assets/pixel_battle/relics/*.svg
assets/pixel_battle/portraits/*.svg
assets/narrative/props/*.svg
assets/narrative/silhouettes/*.svg
```

要求：

- 纯 SVG。
- 无外链。
- 无字体。
- 不内嵌标题文字。
- 不新增第二套战斗背景层。
- 不把路径写死到 GDScript。

### 3.2 参考图线

用于正式美术方向，不直接运行。

```text
art_reference/generated/*.png
```

当前建议保留：

```text
ref_night_knife_camp.png
ref_old_master_saber.png
ref_firearm_seal_mark.png
ref_half_roster_wet.png
ref_empty_wooden_case.png
```

这些图只作为：

```text
风格锚点 / 构图母版 / SVG 临摹参考
```

不要直接写入 `visual_path`。

### 3.3 演出配置线

用于剧情表演区升级。

```text
data/performance_tracks.json
```

目标不是单图替换，而是形成：

```text
background + prop + silhouette + mist + dim + fire_glow + camera_focus
```

---

## 4. 当前主流程 P0 节点

按 `node_status.tsv` 当前主流程，P0 节点为：

```text
military_order
beach_ambush
beach_ambush_aftermath
fishing_village_embers
fishing_village_embers_aftermath
ming_firearm
altered_military_report
transport_officer
transport_officer_aftermath
night_knife_camp
wakou_boss
military_coverup
```

其中最需要马上处理的是：

| 优先级 | 节点 | 原因 | 下一步 |
|---:|---|---|---|
| 1 | `night_knife_camp` | 当前仍复用 `prologue_departure.svg`，但已有高质量参考图 | 新增 `narrative_night_knife_camp.svg` 并改 visual_path |
| 2 | `ming_firearm` | 证据链核心，火器/官造/封泥需要明确 | 新增 / 强化火器刻印、火器 relic |
| 3 | `altered_military_report` | 旧案线索核心，当前需要专属涂改军报视觉 | 新增 `prop_altered_military_report.svg` / relic 强化 |
| 4 | `transport_officer_aftermath` | 半页名册是证据链关键 | 新增 `prop_half_roster_wet.svg`，确认 runtime 是否独立 |
| 5 | `military_coverup` | 第一幕收束，必须有缺页 / 空木匣 / 师父门外 | 新增 `prop_empty_wooden_case.svg` 并挂接 |

---

## 5. P0 立即执行包

### 5.1 生成运行资源

新增：

```text
assets/pixel_battle/backgrounds/narrative_night_knife_camp.svg
assets/narrative/props/prop_old_master_saber.svg
assets/narrative/props/prop_firearm_seal_mark.svg
assets/narrative/props/prop_half_roster_wet.svg
assets/narrative/props/prop_empty_wooden_case.svg
```

### 5.2 更新挂接

修改：

```text
tables/narrative_mvp_node_status.tsv
```

将：

```text
night_knife_camp	...	res://assets/pixel_battle/backgrounds/prologue_departure.svg	...
```

改为：

```text
night_knife_camp	...	res://assets/pixel_battle/backgrounds/narrative_night_knife_camp.svg	...
```

### 5.3 刷新矩阵

更新：

```text
docs/NODE_VISUAL_MATRIX.md
```

将 `night_knife_camp` 从：

```text
VISUAL_REUSED / NEEDS_ASSET
```

更新为：

```text
VISUAL_WIRED / DONE_BASE
```

道具资源标记为：

```text
ASSET_READY_UNWIRED
```

---

## 6. P1 证据链补齐包

目标：玩家不看文字，也能看出旧案证据链。

需要补齐：

```text
黑箭
官泥脚印
火器箱
官造刻印
涂改军报
半页名册
缺页案卷
空木匣
```

建议新增 / 强化：

```text
assets/narrative/props/prop_official_mud_bootprint.svg
assets/narrative/props/prop_altered_military_report.svg
assets/narrative/props/prop_burnt_bowl.svg
assets/narrative/props/prop_military_order_seal.svg
assets/narrative/props/prop_coastal_patrol_map.svg
assets/pixel_battle/relics/relic_ming_firearm.svg
assets/pixel_battle/relics/relic_altered_military_report.svg
```

---

## 7. P2 剧情演出升级包

优先升级这些 `performance_tracks`：

```text
night_knife_camp
military_coverup
ming_firearm
altered_military_report
transport_officer
fishing_village_embers
beach_ambush
```

每个 track 至少包含：

```text
scene_bg
foreground_prop
silhouette
mist / dim / fire_glow
camera_push / focus_target
```

示例：`night_knife_camp`

```text
背景：narrative_night_knife_camp.svg
道具：prop_old_master_saber.svg + prop_firearm_seal_mark.svg
剪影：sil_grinding_saber_shadow.svg
效果：low_fire_glow + damp_mist + slow_push
焦点：师父手停 / 火器刻印
```

---

## 8. P3 角色资产路线

目标：先剪影和半身概念，不急着全套立绘。

| 角色 | 资产规格 | 用途 |
|---|---|---|
| 主角青年武官 | 半身、战斗站姿、头像、剪影 | 主视觉 / 剧情 / 战斗 |
| 师父 / 退伍老兵 | 半身、救援剪影、磨刀剪影、旧刀特写 | 序章 / 夜半磨刀 |
| 小股倭寇首领 | 半身、Boss 剪影、坐火器箱姿态 | Boss 节点 |
| 押运官 | 半身剪影、袖中半页名册姿态 | 押运官节点 |
| 军门官员 | 案房剪影、朱批手势 | 军门压案 |

---

## 9. P4 UI 美术路线

UI 方向不是普通古风，而是：

```text
军令牌
案卷纸
官印封泥
兵册名录
海防图
火器图纸
刀谱残页
```

优先组件：

| UI 组件 | 美术方向 |
|---|---|
| 剧情文本框 | 案卷纸、淡墨边缘、缺页纹理 |
| 选择按钮 | 军令牌 / 木签 / 朱砂批注 |
| 战斗卡牌 | 武学招式谱 / 兵书残页 |
| 敌人意图 | 刀光、枪势、火器、暗箭图标 |
| 势 Posture | 墨痕 / 气势槽 |
| 血量 | 暗朱红封线 |
| 地图节点 | 海防图上的朱砂点 / 官印点 |

---

## 10. P5 展示包装路线

在 P0-P2 基本完成后，再启动：

```text
主视觉 key art
标题字“沧海嘀鸣”
Steam / itch capsule 草案
3-5 张高质量游戏截图
角色概念设定页
```

推荐截图：

```text
1. 黑潮救援
2. 渔村残火
3. 押运官对峙
4. 夜半磨刀
5. 军门压案
```

---

## 11. 里程碑

### Milestone 1：主流程视觉不再明显复用

完成标准：

```text
flow_enabled=true 的节点，不再出现明显不匹配的复用图。
```

当前最大缺口：

```text
night_knife_camp → prologue_departure.svg
```

### Milestone 2：证据链视觉成型

完成标准：

```text
黑箭 / 官泥 / 火器箱 / 官造刻印 / 涂改军报 / 半页名册 / 缺页案卷 / 空木匣
```

这些证据在主流程中都有可见视觉表达。

### Milestone 3：剧情节点有演出

完成标准：

```text
背景 + 道具焦点 + 剪影 + 雾/火光/暗层 + 镜头推进
```

### Milestone 4：可截图展示

完成标准：

```text
5 张截图能讲清楚“明代海疆 + 军门旧案 + 隐晦叙事 + 战斗先于解释”。
```

---

## 12. 下一步执行命令

下一步直接执行：

```text
执行 P0：生成 night_knife_camp SVG 和 4 个 prop SVG，并更新 node_status。
```

预期改动文件：

```text
assets/pixel_battle/backgrounds/narrative_night_knife_camp.svg
assets/narrative/props/prop_old_master_saber.svg
assets/narrative/props/prop_firearm_seal_mark.svg
assets/narrative/props/prop_half_roster_wet.svg
assets/narrative/props/prop_empty_wooden_case.svg
tables/narrative_mvp_node_status.tsv
docs/NODE_VISUAL_MATRIX.md
```

不应改动：

```text
data/enemy_manifest.json
data/battle_scene_manifest.json
战斗 GDScript
```
