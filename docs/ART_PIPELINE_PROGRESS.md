# 《沧海嘀鸣》美术表现推进看板

> 当前目标：从“纯文字 + 简单色块占位”推进到“极简碎片化叙事 + 明代海疆国风主视觉 + 数据驱动剧情演出 + 大地图节点推进 + battle_id 驱动战斗场景”的可见 MVP。
>
> 当前美术方向：青年明代武官、明制札甲、深绛红战袍、水墨海岸、宣纸背景、海雾、远崖、城墙、小船、低饱和、强剪影、家国情怀、风起沧海。
>
> 当前叙事方向：极度压缩、碎片化、隐晦叙事、动作先于解释、案情缺页、潮声反复、箭从岸上来。

---

## 0. 总体规范：剧情 / 文本 / 大地图 / 战斗分层

```text
剧情：NarrativeDemo
- 上方表演区：场景主视觉、人物剪影、雾、火光、暗层、镜头
- 下方操作区：文本、状态、选择、滚动按钮
- 由 node_id / step_index 加载剧情演出
- 节点内不再显示节点线 / 行军路线

文本：Fragmented Narrative Layer
- 文本不再长段解释
- 单句尽量短
- 不直说阴谋，只说痕迹
- 不交代完整案情，只给碎片
- 序章、第一幕、结局统一为隐晦碎片节奏

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

## 1. 新增：碎片化 MVP 叙事脚本

```text
docs/NARRATIVE_MVP_SCRIPT_FRAGMENTED.md
scripts/narrative_demo_fragmented_controller.gd
scenes/NarrativeDemo.tscn
```

当前架构：

```text
NarrativeDemo.tscn
→ narrative_demo_fragmented_controller.gd
→ narrative_demo_cinematic_controller.gd
→ narrative_demo_formal_controller.gd
```

接入策略：

```text
保留机制：职业选择、战斗桥接、大地图、节点推进、结算
保留演出：背景、雾、火光、人物剪影、镜头、performance_tracks.json
只覆写文本：序章文本、第一幕正文、场景短句、选项文案、结局文案
```

文本风格规则：

```text
[x] 极度压缩
[x] 碎片化
[x] 隐晦叙事
[x] 动作先于解释
[x] 不说“阴谋”，只说“缺页、暗箭、火器、名册”
[x] 不说“真相”，只说“痕迹”
[x] 每个节点只给一个核心意象
[x] 战斗前不解释敌人是谁，只说明“他挡路”
[x] 战斗后只掉下一枚碎片
```

序章核心节奏：

```text
黑。
潮声很近。
有人在跑。

父亲。
柴堆。
别出声。

死人也不知道。

换我。

箭从黑处来。
不是海上。
不是倭人。

十年。
该走了。
```

第一幕核心节奏：

```text
军令巡海：军令压在案上，最后一行被墨盖住。
海边伏击：枪尖从芦苇里出来，靴上有官泥。
明制火器：箱子裂开，铸印还在，不是倭物。
押运官：雨打在名册上，墨开始散。
破船 Boss：你来晚了，也来早了。
军门压案：案卷少了一页，上官说倭患已平。
```

---

## 2. 剧情 UI 布局规范

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

## 3. 已完成：剧情电影化演出 + 大地图层

```text
scripts/narrative_demo_cinematic_controller.gd
scenes/NarrativeDemo.tscn
data/performance_tracks.json
```

当前状态：

```text
[x] cinematic controller 稳定承载演出层
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

## 4. 大地图 / 海疆行军图

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

---

## 5. 已完成：剧情资源 SVG 占位升级

```text
assets/pixel_battle/backgrounds/key_visual_canghai_diming.svg
assets/pixel_battle/backgrounds/prologue_black_tide.svg
assets/pixel_battle/backgrounds/prologue_master_rescue.svg
assets/pixel_battle/backgrounds/prologue_arrow_silence.svg
assets/pixel_battle/backgrounds/prologue_departure.svg
assets/pixel_battle/backgrounds/narrative_military_order.svg
assets/pixel_battle/backgrounds/narrative_beach_ambush.svg
assets/pixel_battle/relics/relic_ming_firearm.svg
assets/pixel_battle/portraits/transport_officer.svg
assets/pixel_battle/portraits/wakou_leader.svg
assets/pixel_battle/backgrounds/narrative_military_coverup.svg
```

当前节点表现：

```text
[x] 军令巡海：庄重军令演出
[x] 海边伏击：强雾、快速推进、紧张感
[x] 明制火器：证物特写，火器箱成为主体
[x] 失械案押运官：雨雾对峙压迫感
[x] 破船 Boss：强雾、火光、主角入镜，高潮节点
[x] 军门压案：高暗度、低火光、压抑收束
```

---

## 6. 战斗场景 battle_id 加载体系

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

---

## 7. NarrativeBattleContext 已支持 battle_id

```text
scripts/narrative_battle_context.gd
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

## 8. 当前验收状态

```text
[x] Web 构建稳定，无 Could not resolve class
[x] NarrativeDemo 已切到 fragmented controller
[x] 序章文本已改为碎片化节奏
[x] 第一幕 6 个节点正文已改为隐晦碎片叙事
[x] 选项文案已压缩
[x] 结局文案已重写为“潮声还在”
[x] 剧情表演区显示场景主视觉背景
[x] 下方操作区完整显示选项
[x] 剧情—战斗—剧情闭环不受影响
[x] data/performance_tracks.json 已生效
[x] 明制火器证物节点可见
[x] 大地图层已接入第一幕
[x] 节点内不再显示节点线 / 行军图按钮组
[ ] fragmented controller 在 Web 端待复验
[ ] 大地图节点点击推进待复验
[ ] MainVisual 按 battle_id 切换战斗场景待复验
```

文本验收建议：

```text
1. 序章每屏都是短句，不再长解释
2. 第一幕节点正文不再完整解释案情
3. 明制火器只强调“铸印还在，不是倭物”
4. 破船 Boss 不说明真相，只留下“来晚了 / 来早了”
5. 军门压案不揭幕后，只留下“案卷少了一页”
6. 结局只告诉玩家：倭寇从海上来，箭从岸上来
```

---

## 9. 下一批优先级

### P0：碎片文本与演出节拍对齐

```text
让短句节奏与背景切换、雾、火光、人物入镜更贴合。
```

### P1：大地图视觉正式化

```text
world_map_canghai_act1.svg
world_map_node_current.svg
world_map_node_locked.svg
world_map_route_line.svg
```

### P2：战斗人物立绘替换

```text
hero_spearman_battle.svg
hero_blademaster_battle.svg
master_veteran_battle.svg
enemy_spearman_battle.svg
transport_officer_battle.svg
wakou_leader_battle.svg
```

---

## 10. 当前一句话结论

```text
MVP 文本层已从说明型叙事切换为碎片化隐晦叙事：序章、第一幕、结局都围绕“潮声、缺页、火器、暗箭”展开；演出层、大地图层和战斗 battle_id 场景系统继续保留。下一阶段应把碎片文本与镜头节拍进一步对齐。
```
