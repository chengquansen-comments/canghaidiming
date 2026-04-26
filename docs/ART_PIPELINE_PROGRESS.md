# 《沧海嘀鸣》美术表现推进看板

> 当前目标：从“纯文字 + 简单色块占位”推进到“明代海疆国风主视觉 + 数据驱动剧情演出 + 大地图节点推进 + battle_id 驱动战斗场景”的可见 MVP。
>
> 当前美术方向：青年明代武官、明制札甲、深绛红战袍、水墨海岸、宣纸背景、海雾、远崖、城墙、小船、低饱和、强剪影、家国情怀、风起沧海。

---

## 0. 总体规范：剧情 / 大地图 / 战斗分层

```text
剧情：NarrativeDemo
- 上方表演区：场景主视觉、人物剪影、雾、火光、暗层、镜头
- 下方操作区：文本、状态、选择、滚动按钮
- 由 node_id / step_index 加载剧情演出
- 节点内不再显示节点线 / 行军路线

大地图：World Map Layer
- 从节点内抽出的行军图路线
- 显示第一幕整体路线、节点、连线、当前所在位置
- 节点可点击，复用原地图推进规则
- 只在进入第一幕后显示；序章不显示

战斗：MainVisual
- 所有战斗场景必须按 battle_id 加载
- 进入战斗必须先 reset 旧视觉状态
- 不允许复用上一场背景残留
- 不允许只按敌人类型决定背景
- 剧情战斗和测试战斗都必须走 battle_id
- 战斗背景直接写入原 background_texture，不再新建第二套背景层
```

---

## 1. 剧情 UI 布局规范

```text
Narrative UI 采用明确上下分割：

上方：表演区（Performance Area）
- 承载场景主视觉（SVG / PNG / AI 图）
- 用于表现人物、环境、情绪、叙事氛围
- 可叠加暗层 / 雾层 / 火光 / 人物剪影
- 第一幕后叠加大地图层，显示整体节点路线

下方：操作区（Operation Area）
- 承载剧情文本（body）
- 承载选项按钮（choices）
- 承载状态提示（hint / vars）
- 承载战斗桥接按钮
- 不再承载节点线 / 行军图按钮组
- 必须保证滚动与点击优先级

实现约束：
- 理想比例：上方约 2/3 表演区，下方约 1/3 操作区
- 实际运行：操作区有最小高度保护，小屏幕时自动压缩表演区，优先保证选项可见
- 禁止再使用“中间一小块插图”的旧结构
- 所有剧情场景图默认作为表演区背景，而不是 UI 元素
- 原 map_label / map_buttons_box 只作为旧兼容，不再显示节点路线
```

---

## 2. 已完成：剧情电影化演出 + 大地图层

```text
scripts/narrative_demo_cinematic_controller.gd
scenes/NarrativeDemo.tscn
data/performance_tracks.json
```

当前架构：

```text
NarrativeDemo.tscn
→ narrative_demo_cinematic_controller.gd
→ narrative_demo_formal_controller.gd
```

当前状态：

```text
[x] 单文件 cinematic controller，避免多级继承解析问题
[x] JSON 数据驱动演出已重新挂回
[x] 序章按 step_index 自动切换背景
[x] 第一幕按 node_id 自动切换背景
[x] 表演区背景铺满
[x] 下方操作区最小高度保护
[x] 雾层移动
[x] 火光脉冲
[x] 暗层呼吸
[x] 师父 / 主角剪影入镜
[x] 镜头轻推、横移、局部节奏变化
[x] 新增 CinematicWorldMapLayer
[x] 第一幕节点线已从节点内抽出，成为大地图节点
[x] 节点内不再显示行军图节点线
```

---

## 3. 新增：大地图 / 海疆行军图

```text
CinematicWorldMapLayer
WorldMapPanel
WorldMapNodesRow
```

显示规则：

```text
序章：不显示大地图
第一幕：显示海疆行军图
节点内：不再显示旧行军图按钮组
```

大地图节点规则：

```text
◆ 当前：当前所在节点
● 已过：已经经过的节点
◎ 可前往：下一可选节点
○ 未开放：后续未开放节点
```

当前路线：

```text
军令巡海 ━━ 海边伏击 ━━ 明制火器 ━━ 失械案押运官 ━━ 破船 Boss ━━ 军门压案
```

交互规则：

```text
点击当前节点：提示当前节点
点击已过节点：提示已走过
点击下一节点：可推进，并获得默认行军收益
点击未开放节点：按钮禁用
```

---

## 4. 已完成：剧情资源 SVG 占位升级

### 4.1 主视觉封面

```text
assets/pixel_battle/backgrounds/key_visual_canghai_diming.svg
```

### 4.2 序章专用表演图

```text
assets/pixel_battle/backgrounds/prologue_black_tide.svg
assets/pixel_battle/backgrounds/prologue_master_rescue.svg
assets/pixel_battle/backgrounds/prologue_arrow_silence.svg
assets/pixel_battle/backgrounds/prologue_departure.svg
```

### 4.3 第一幕节点表演图

```text
assets/pixel_battle/backgrounds/narrative_military_order.svg
assets/pixel_battle/backgrounds/narrative_beach_ambush.svg
assets/pixel_battle/relics/relic_ming_firearm.svg
assets/pixel_battle/portraits/transport_officer.svg
assets/pixel_battle/portraits/wakou_leader.svg
assets/pixel_battle/backgrounds/narrative_military_coverup.svg
```

当前状态：

```text
[x] 军令巡海：庄重军令演出
[x] 海边伏击：强雾、快速推进、紧张感
[x] 明制火器：证物特写，火器箱成为主体
[x] 失械案押运官：雨雾对峙压迫感
[x] 破船 Boss：强雾、火光、主角入镜，高潮节点
[x] 军门压案：高暗度、低火光、压抑收束
```

---

## 5. 战斗场景 battle_id 加载体系

```text
data/battle_scene_manifest.json
scripts/battle_controller_visual_scene_manifest.gd
scenes/MainVisual.tscn
```

当前架构：

```text
MainVisual.tscn
→ battle_controller_visual_scene_manifest.gd
→ battle_controller_visual_narrative_formal.gd
```

硬规范：

```text
[x] 每场战斗必须有 battle_id
[x] 进入战斗先 reset 旧战斗视觉
[x] 再按 battle_id 加载背景
[x] 剧情战斗从 NarrativeBattleContext.get_battle_id() 读取
[x] 测试入口按角色映射 test_spearman_duel / test_blademaster_duel
[x] 不再允许上一场背景残留
[x] 不新建第二套背景层
[x] battle_id 背景直接写入原 background_texture.texture
```

当前 battle_id 覆盖：

```text
prologue_master_rescue      → 黑潮救援
first_act_beach_ambush      → 海边伏击
first_act_transport_officer → 押运官对峙
first_act_wakou_boss        → 破船决战
test_spearman_duel          → 枪术试战
test_blademaster_duel       → 刀术试战
fallback                    → 默认接敌
```

当前战斗背景资源：

```text
assets/pixel_battle/backgrounds/battle_bg_black_tide.svg
assets/pixel_battle/backgrounds/battle_bg_coast_ambush.svg
assets/pixel_battle/backgrounds/battle_bg_transport_road.svg
assets/pixel_battle/backgrounds/battle_bg_broken_ship.svg
assets/pixel_battle/backgrounds/battle_bg_training_ground.svg
```

---

## 6. NarrativeBattleContext 已支持 battle_id

```text
scripts/narrative_battle_context.gd
```

当前状态：

```text
[x] 新增 battle_id 元信息
[x] set_request(encounter_id, source_node_id, battle_id="") 支持显式 battle_id
[x] 未传 battle_id 时，自动从 encounter_id 映射
[x] get_battle_id() 提供给战斗场景加载
[x] debug_text / battle_mapping_debug_text 已显示 battle_id
```

当前默认映射：

```text
enc_prologue_master_rescue → prologue_master_rescue
enc_beach_ambush           → first_act_beach_ambush
enc_transport_officer      → first_act_transport_officer
enc_wakou_boss             → first_act_wakou_boss
其他                       → source_node_id 或 fallback
```

---

## 7. 当前验收状态

```text
[x] Web 构建稳定，无 Could not resolve class
[x] NarrativeDemo 正常打开
[x] 剧情表演区显示场景主视觉背景
[x] 下方操作区完整显示选项
[x] 剧情—战斗—剧情闭环不受影响
[x] data/performance_tracks.json 已生效
[x] 明制火器证物节点可见
[x] 大地图层已接入第一幕
[x] 节点内不再显示节点线 / 行军图按钮组
[ ] 大地图节点点击推进待验收
[ ] MainVisual 按 battle_id 切换战斗场景待复验
[ ] 多场战斗切换后无背景残留待复验
```

大地图验收建议：

```text
1. 序章不显示大地图
2. 出山进入第一幕后，表演区上方显示“海疆行军图”
3. 节点内下方操作区不再出现“行军图操作”节点线
4. 当前节点显示 ◆ 当前
5. 已过节点显示 ● 已过
6. 下一节点显示 ◎ 可前往
7. 未开放节点禁用
8. 点击下一节点仍能推进
```

战斗场景验收建议：

```text
1. 序章师父战显示 battle_id=prologue_master_rescue，背景为黑潮救援
2. 海边伏击显示 battle_id=first_act_beach_ambush，背景为海岸伏击
3. 押运官战显示 battle_id=first_act_transport_officer，背景为押运路
4. 破船 Boss 显示 battle_id=first_act_wakou_boss，背景为破船决战
5. 测试枪手入口显示 test_spearman_duel
6. 测试刀客入口显示 test_blademaster_duel
7. 任意两场连续进入，旧背景不残留
8. 人物、格位、预览箭头必须始终在背景之上
```

---

## 8. 下一批美术优先级

### P0：大地图视觉正式化

```text
world_map_canghai_act1.svg
world_map_node_current.svg
world_map_node_locked.svg
world_map_route_line.svg
```

目标：

```text
把当前按钮式大地图升级为真正的海疆航路图：海岸线、船路、军门、破船、证物点。
```

### P1：战斗人物立绘替换

```text
hero_spearman_battle.svg
hero_blademaster_battle.svg
master_veteran_battle.svg
enemy_spearman_battle.svg
transport_officer_battle.svg
wakou_leader_battle.svg
```

目标：

```text
让战斗中的人物也从测试色块 / 旧图转向国风剪影立绘。
```

### P2：战斗前景层

```text
battle_fg_reeds.svg
battle_fg_transport_cart.svg
battle_fg_broken_ship_debris.svg
battle_fg_firearm_crate.svg
```

目标：

```text
让战斗背景不只是铺底，而有前景遮挡、空间层次和战场识别度。
注意：前景层只能放在低透明、低遮挡区域，不能遮住格位核心信息。
```

---

## 9. 当前一句话结论

```text
剧情美术管线已进入“数据驱动电影化演出 + 大地图节点推进”阶段；第一幕节点线已从节点内抽出，成为表演区独立海疆行军图。战斗美术管线已进入“battle_id 驱动原背景层加载”阶段，不再使用第二套背景层。
```
