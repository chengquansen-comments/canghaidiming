# 《沧海嘀鸣》美术表现推进看板

> 当前目标：从“纯文字 + 简单色块占位”推进到“明代海疆国风主视觉 + 数据驱动剧情演出 + battle_id 驱动战斗场景”的可见 MVP。
>
> 当前美术方向：青年明代武官、明制札甲、深绛红战袍、水墨海岸、宣纸背景、海雾、远崖、城墙、小船、低饱和、强剪影、家国情怀、风起沧海。

---

## 0. 总体规范：剧情与战斗分层

```text
剧情：NarrativeDemo
- 上方表演区：场景主视觉、人物剪影、雾、火光、暗层、镜头
- 下方操作区：文本、状态、选择、滚动按钮
- 由 node_id / step_index 加载剧情演出

战斗：MainVisual
- 所有战斗场景必须按 battle_id 加载
- 进入战斗必须先 reset 旧视觉状态
- 不允许复用上一场背景残留
- 不允许只按敌人类型决定背景
- 剧情战斗和测试战斗都必须走 battle_id
- 战斗背景 / 雾 / 暗层 / 强调光必须在人物、格位、预览箭头之后方
```

---

## 1. 剧情 UI 布局规范

```text
Narrative UI 采用明确上下分割：

上方：表演区（Performance Area）
- 承载场景主视觉（SVG / PNG / AI 图）
- 用于表现人物、环境、情绪、叙事氛围
- 不放交互按钮
- 可叠加暗层 / 雾层 / 火光 / 人物剪影

下方：操作区（Operation Area）
- 承载剧情文本（body）
- 承载选项按钮（choices）
- 承载状态提示（hint / vars）
- 必须保证滚动与点击优先级

实现约束：
- 理想比例：上方约 2/3 表演区，下方约 1/3 操作区
- 实际运行：操作区有最小高度保护，小屏幕时自动压缩表演区，优先保证选项可见
- 禁止再使用“中间一小块插图”的旧结构
- 所有剧情场景图默认作为表演区背景，而不是 UI 元素
```

---

## 2. 已完成：剧情电影化演出

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
```

---

## 3. 已完成：剧情资源 SVG 占位升级

### 3.1 主视觉封面

```text
assets/pixel_battle/backgrounds/key_visual_canghai_diming.svg
```

---

### 3.2 序章专用表演图

```text
assets/pixel_battle/backgrounds/prologue_black_tide.svg
assets/pixel_battle/backgrounds/prologue_master_rescue.svg
assets/pixel_battle/backgrounds/prologue_arrow_silence.svg
assets/pixel_battle/backgrounds/prologue_departure.svg
```

---

### 3.3 第一幕节点表演图

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

## 4. 新增：战斗场景 battle_id 加载体系

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
[x] 再按 battle_id 加载背景 / 雾 / 暗层 / 强调色 / 场景标题
[x] 剧情战斗从 NarrativeBattleContext.get_battle_id() 读取
[x] 测试入口按角色映射 test_spearman_duel / test_blademaster_duel
[x] 不再允许上一场背景残留
[x] 战斗背景层 z_index=-200，z_as_relative=false
[x] 战斗雾 / 暗层 / 强调光 z_index=-190 到 -188，z_as_relative=false
[x] 场景标签 z_index=250，不遮挡格位和人物主体
[x] 背景层全部 mouse_filter=IGNORE，不参与鼠标交互
```

### 4.1 战斗层级安全规则

```text
必须遵守：
- battle_scene_bg 永远在最底层
- battle_scene_mist / battle_scene_dim / battle_scene_accent 只能做低透明度环境层
- 不允许覆盖 stage_layer、grid、fighter sprite、preview ghost、preview arrow
- 如果人物或格位不可见，优先检查 z_index，而不是调美术资源
- mist / dim / accent 参数会在 controller 内二次收敛，避免压死战斗信息
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

当前战斗场景表现能力：

```text
background：战斗背景图
mist：战斗雾层强度（controller 内二次收敛）
dim：战斗暗层强度（controller 内二次收敛）
accent：朱砂火光 / 危险强调（controller 内二次收敛）
camera_zoom：镜头推进
camera_pan_x / camera_pan_y：镜头横移 / 纵移
label：左上角战斗场景标题与 battle_id 诊断
```

---

## 5. NarrativeBattleContext 已支持 battle_id

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

## 6. 当前验收状态

```text
[x] Web 构建稳定，无 Could not resolve class
[x] NarrativeDemo 正常打开
[x] 剧情表演区显示场景主视觉背景
[x] 下方操作区完整显示选项
[x] 剧情—战斗—剧情闭环不受影响
[x] data/performance_tracks.json 已生效
[x] 明制火器证物节点可见
[x] 战斗背景层级已修复为后景，不应遮挡人物和格位
[ ] MainVisual 按 battle_id 切换战斗场景待复验
[ ] 多场战斗切换后无背景残留待复验
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
8. 人物、格位、预览箭头必须始终在背景、雾、暗层之上
```

---

## 7. 下一批美术优先级

### P0：战斗人物立绘替换

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

---

### P1：战斗前景层

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

### P2：正式 PNG 替换

```text
prologue_black_tide.png
prologue_master_rescue.png
narrative_military_order.png
narrative_beach_ambush.png
battle_bg_coast_ambush.png
battle_bg_broken_ship.png
```

目标：

```text
将 SVG 高级占位逐步替换为 AI 生成或正式绘制 PNG，提升观感上限。
```

---

## 8. 当前一句话结论

```text
剧情美术管线已进入“数据驱动电影化演出”阶段；战斗美术管线已进入“battle_id 驱动场景加载”阶段。最新修复已将战斗背景层压到负 z-index 后景，避免遮挡人物、格位与预览箭头；下一阶段应推进战斗人物立绘和受控前景层。
```
