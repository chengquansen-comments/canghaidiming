# 《沧海嘀鸣》美术表现推进看板

> 当前目标：从“纯文字 + 简单色块占位”推进到“配置化碎片叙事 + 独立敌人配置 + 敌人牌组与行为配置化 + 明代海疆国风主视觉 + 数据驱动剧情演出 + 大地图节点推进 + battle_id 驱动战斗场景”的可见 MVP。
>
> 当前美术方向：青年明代武官、明制札甲、深绛红战袍、水墨海岸、宣纸背景、海雾、远崖、城墙、小船、低饱和、强剪影、家国情怀、风起沧海。
>
> 当前叙事方向：极度压缩、碎片化、隐晦叙事、动作先于解释、案情缺页、潮声反复、箭从岸上来。

---

## 0. 总体规范：剧情 / 文本 / 敌人 / 大地图 / 战斗分层

```text
剧情：NarrativeDemo
- 上方表演区：场景主视觉、人物剪影、雾、火光、暗层、镜头
- 下方操作区：文本、状态、选择、滚动按钮
- 由 node_id / step_index 加载剧情演出
- 节点内不再显示节点线 / 行军路线

文本：Configurable Fragmented Narrative Layer
- 节点文本、场景短句、选项、战斗触发、battle_id、enemy_id 进入 data/narrative_mvp_nodes.json
- controller 只负责读取、渲染、桥接战斗
- 文本不再长段解释
- 单句尽量短
- 不直说阴谋，只说痕迹
- 不交代完整案情，只给碎片

敌人：Enemy Manifest Layer
- 完整敌人配置独立进入 data/enemy_manifest.json
- narrative_mvp_nodes.json 只引用 encounter_id / battle_id / enemy_id
- enemy_manifest.json 负责 enemy stat / role_sheet / deck / AI 意图权重 / 半血行为 / reward
- NarrativeBattleContext 优先读取 enemy_manifest，失败时回退兜底

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

## 1. MVP 叙事节点配置表

```text
data/narrative_mvp_nodes.json
scripts/narrative_mvp_data.gd
scripts/narrative_demo_fragmented_controller.gd
```

配置表当前管理内容：

```text
[x] prologue.steps：序章十二拍文本
[x] prologue.steps[].combat：序章战斗触发、encounter_id、battle_id、enemy_id
[x] prologue.career_choices：职业选择文案
[x] nodes[].id/title/scene/text：第一幕节点文本
[x] nodes[].dialogue：节点短对白/碎片信息
[x] nodes[].combat：战斗触发、encounter_id、battle_id、enemy_id、战前/战后碎片
[x] nodes[].choices：选项文案、结果文本、效果字段
[x] ending：结局标题、场景短句、结局正文
[x] hints：通用提示覆写
```

当前接入状态：

```text
[x] fragmented controller 优先读取 data/narrative_mvp_nodes.json
[x] JSON 不存在或字段缺失时回退代码内置文本
[x] NarrativeDemo 不再需要为每个文本改 GDScript
[x] NarrativeMvpData 通用读取器已新增
```

---

## 2. 独立敌人配置表

```text
data/enemy_manifest.json
scripts/narrative_enemy_manifest.gd
scripts/narrative_battle_context.gd
```

enemy_manifest 当前管理内容：

```text
[x] encounters：encounter_id 到 battle_id / enemy_id / difficulty / label 的映射
[x] enemies：enemy_id 到完整敌人配置的映射
[x] display_name：敌人显示名
[x] narrative_identity：叙事身份
[x] weapon：武器
[x] role_sheet：战斗角色模板
[x] max_hp / max_posture / start_posture：敌人数值
[x] intent_style：AI 行为风格
[x] behavior_tags：行为标签
[x] preferred_intents：偏好意图描述
[x] intent_weights：意图权重
[x] phase_behaviors：阶段行为 / 半血行为 / 濒死行为
[x] deck：敌人招式牌组配置
[x] ai_note：AI 设计说明
[x] reward：战斗奖励
```

当前覆盖敌人：

```text
enemy_blademaster_prologue_raider   → 袭村倭寇刀手
enemy_spearman_beach_ambush         → 敌方枪手
enemy_blademaster_transport_officer → 失械案押运官
enemy_blademaster_wakou_leader      → 小股倭寇首领
enemy_spearman_fallback             → 默认敌方枪手
```

本次更新：

```text
[x] 已将测试用“海滩测试枪手 / HP 99 / 势 9-12”恢复为正式“敌方枪手 / HP 26 / 势 4-10”
[x] 所有敌人新增 deck 字段，承载招式牌配置
[x] 所有敌人新增 intent_weights 字段，承载意图选择权重
[x] 所有敌人新增 phase_behaviors 字段，承载默认 / 半血 / 濒死阶段行为
[x] enemy_manifest meta.version 升级为 2
```

当前接入状态：

```text
[x] NarrativeEnemyManifest 可读取 data/enemy_manifest.json
[x] NarrativeBattleContext.get_battle_mapping() 优先读取 enemy_manifest
[x] enemy_manifest 读取失败时回退默认兜底敌人
[x] battle_mapping_debug_text 显示 enemy_source=manifest / fallback
[x] 运行时敌人数值链路已通过实机验收
[ ] deck / intent_weights / phase_behaviors 是否已被战斗 AI 完整消费，需下一轮专项验收
```

设计边界：

```text
narrative_mvp_nodes.json：负责“剧情里发生了什么”
enemy_manifest.json：负责“敌人是谁、怎么打、掉什么”
battle_scene_manifest.json：负责“这场战斗在哪里打、背景是什么”
performance_tracks.json：负责“剧情画面怎么演”
```

---

## 3. 碎片化 MVP 叙事脚本

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
文本读取：优先 data/narrative_mvp_nodes.json，失败时回退内置常量
敌人读取：优先 data/enemy_manifest.json，失败时回退默认敌人
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

---

## 4. 剧情电影化演出 + 大地图层

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
[x] CinematicWorldMapLayer 已接入
[x] 第一幕节点线已从节点内抽出，成为大地图节点
[x] 节点内不再显示行军图节点线
```

---

## 5. 大地图 / 海疆行军图

```text
CinematicWorldMapLayer
WorldMapPanel
WorldMapNodesRow
```

当前路线：

```text
军令巡海 ━━ 海边伏击 ━━ 明制火器 ━━ 失械案押运官 ━━ 破船 Boss ━━ 军门压案
```

---

## 6. 战斗场景 battle_id 加载体系

```text
data/battle_scene_manifest.json
scripts/battle_controller_visual_scene_manifest.gd
scenes/MainVisual.tscn
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

## 7. 当前验收状态

```text
[x] Web 构建稳定，无 Could not resolve class
[x] NarrativeDemo 已切到 fragmented controller
[x] 新增 data/narrative_mvp_nodes.json
[x] 新增 data/enemy_manifest.json
[x] 节点文本 / 场景短句 / 选项 / 战斗触发 / battle_id 已配置化
[x] 敌人完整数值 / 行为标签 / 奖励已进入 enemy_manifest
[x] 敌人 deck / intent_weights / phase_behaviors 已进入 enemy_manifest
[x] fragmented controller 优先读取节点配置表
[x] NarrativeBattleContext 优先读取 enemy_manifest
[x] enemy_manifest 读取失败时有 fallback
[x] enemy_manifest 运行时数值链路已实机验收通过
[x] 大地图层已接入第一幕
[x] 节点内不再显示节点线 / 行军图按钮组
[ ] Web 端复验海边伏击正式数值已恢复
[ ] deck 是否实际由 enemy_manifest 驱动待复验
[ ] intent_weights / phase_behaviors 是否实际进入 AI 决策待专项实现或复验
```

配置化验收建议：

```text
1. 进入海边伏击，敌人应恢复为“敌方枪手”，HP=26，势=4/10
2. 修改 data/enemy_manifest.json 某个敌人的 max_hp 后，战斗内敌人血量随之变化
3. 修改 data/enemy_manifest.json 的 display_name 后，战斗内敌人名随之变化
4. 修改 enemies.*.deck 中某张牌的 damage 后，敌人持牌摘要或实际牌效应随之变化
5. battle_mapping_debug_text 中应显示 enemy_source=manifest
6. JSON 出错时，游戏仍回退 fallback，不应白屏
```

---

## 8. 下一批优先级

### P0：deck 字段实际消费验收

```text
确认 MainVisual 敌人实际持牌是否来自 enemy_manifest.enemies.*.deck，而不是仍然使用 GDScript 内置 _enemy_spear_cards / _enemy_officer_cards / _enemy_boss_cards。
```

### P1：intent_weights / phase_behaviors 接入 AI 决策

```text
当前 enemy_manifest 已具备意图权重和阶段行为配置；下一步需要让敌人选牌 / 出招 AI 消费这些字段，形成半血行为切换和 Boss 阶段变化。
```

### P2：碎片文本与演出节拍对齐

```text
让短句节奏与背景切换、雾、火光、人物入镜更贴合。
```

---

## 9. 当前一句话结论

```text
MVP 已完成四层配置拆分，并将 enemy_manifest 扩展到敌人牌组、意图权重和阶段行为层：narrative_mvp_nodes 管剧情文本与战斗触发，enemy_manifest 管敌人数值 / deck / intent_weights / phase_behaviors / reward，battle_scene_manifest 管 battle_id 战斗场景，performance_tracks 管剧情演出。海边伏击测试数值已恢复正式配置，下一步应专项验收 deck 与 AI 行为是否真正消费 manifest。
```
