# 《大明之沧海嘀鸣》叙事 MVP 进度看板

> 当前分支：`feature/symmetry-gameplay`  
> 当前阶段：P0 Web 构建稳定已恢复；剧情 MVP 已切到安全版 controller；安全版已完成“压缩序章 + 序章师父救场战 + 出山职业选择 + 玩家单局数据初始化与成长 + 六列行军图 + 地图点击 + 三变量成长 + 战斗占位 + 场景信息分层 + 结局闭环 + UI 分层 + 操作区滚动修复 + 真实战斗 V1 单向跳转 + MainVisual 叙事上下文诊断 + Battle Result 诊断 + 战斗胜利后继续剧情闭环 + CanvasLayer 无条件返回剧情控件 + Engine metadata 上下文持久化兜底 + encounter_id 接战映射诊断 + 关卡信息可见性修复 + 按推荐接敌过渡按钮 + 四场 MVP 战斗敌人配置 + 顶部敌人详细配置横条”。返回剧情闭环与关卡信息可见性均已验收通过。  
> 核心原则：继续走安全线，不恢复旧 `scripts/narrative/*` 复杂链路；不使用 `HScrollContainer`；不直接改战斗规则；不破坏现有战斗测试入口；不重构 `web_shell.html`。

---

## 1. 当前目标

叙事 MVP 当前验证：

```text
玩家能在 Web 稳定环境里走完：
倭寇袭村
→ 师父救命
→ 序章师父救场战
→ 敌人临死：“军……”
→ 暗箭灭口
→ 师父：“别看。”
→ 十年后出山
→ 选择出山职业
→ 初始化玩家数据
→ 军令巡海
→ 海边伏击
→ 明制火器
→ 失械案押运官
→ 破船 Boss
→ 军门压案
→ 结局
```

真实战斗 V1.5 接入目标已达成：

```text
剧情战斗节点点击“请求战斗”
→ 写入 encounter_id / source_node_id
→ 同步写入 Engine metadata
→ 跳转 MainVisual.tscn
→ MainVisual 继续走现有角色选择入口
→ MainVisual 顶部横条显示玩家数据 + 敌人详细配置
→ MainVisual 右上角 CanvasLayer 无条件显示“返回剧情”控件
→ 点击后按当前 HP 推断结果，无法推断时按 win 保底
→ 将 result 同步写入 Engine metadata
→ 返回 NarrativeDemo
→ NarrativeDemo 从 NarrativeBattleContext / Engine metadata 消费 battle result
→ 战斗胜利后推动玩家数据成长
```

V3 当前目标：

```text
从“只显示接战映射”推进到“出山职业选择 + 玩家数据贯穿 + 敌人配置数据层 + 顶部详细配置横条 + 按推荐接敌”的安全过渡入口。
不直接绕过现有角色选择；不改 BattleStateMachine；不改卡牌/伤害/AI 规则。
```

当前仍不做：

```text
不直接改 BattleStateMachine
不改 resolve_intent
不改 finish_round
不做复杂失败惩罚
不新增复杂敌人体系
不强制绕过 MainVisual 原角色选择入口
```

---

## 2. 当前已完成实装

### 2.1 Web 构建稳定修复

```text
[x] 新增 scripts/narrative/.gdignore，临时隔离旧复杂叙事链路
[x] NarrativeDemo.tscn 切到 parser-safe controller
[x] 不再依赖 HScrollContainer
[x] 不再依赖 NarrativeDemoController class_name 解析
[x] 修复 visual diagnostics 中 class_name 作为变量名导致的 Parser Error
[x] 修复 BattleStateMachine preload 名称与父类成员冲突问题
[x] safe controller 已重新构建通过用户验收
```

对应提交：

```text
9228e5fc8dffc1a4de022521a84d11aca8a5b174  Ignore legacy narrative scripts for parser stability
90d405523f565a4d5ecf0ab36f247c9893634941  Use parser-safe narrative demo controller
c30ea1b5a6017ca956ecfbc512b074d484bf731c  Fix visual diagnostics parser variable name
6f68afe348bb66a3ecd052bcd1d5ccd08f48dec1  Fix battle state machine name collision in narrative wrapper
```

---

### 2.2 安全版 NarrativeDemo Controller

文件：

```text
scripts/narrative_demo_safe_controller.gd
```

当前已支持：

```text
[x] 压缩序章可播放
[x] 序章中文显示正常
[x] 序章“师父入场”段接入真实战斗跳转
[x] 序章师父救场战返回后继续到“敌人临死：军……”
[x] 序章可跳过师父救场战，按胜利继续
[x] “十年后：该出山了。”改为出山职业选择
[x] 当前职业可选：长枪武官 / 腰刀武官
[x] 选择职业后初始化玩家数据：职业、武器、HP、势、武境、胜场
[x] 选择职业后进入行军图第一节点：军令巡海
[x] 变量栏显示三叙事变量 + 玩家数据
[x] 节点正文显示当前玩家数据
[x] 战斗胜利后玩家成长：最大 HP +2，武境 +1，HP/势回满，胜场 +1
[x] 旧物节点默认收益可增加玩家势上限
[x] 六列行军图文本展示：军令 / 初遇 / 疑点 / 压迫 / 破船 / 军门
[x] 六列行军图按钮布局：每列一个 VBoxContainer，外层 HBoxContainer
[x] 地图状态标记：▶ 当前 / ● 已走 / ◎ 可前往 / ○ 未开放
[x] 地图按钮可点击
[x] 点击 ◎ 可前往节点可推进
[x] 点击 ▶ 当前节点只提示，不推进
[x] 点击 ● 已走节点只提示，不推进
[x] 点击 ○ 未开放节点只提示，不推进
[x] 地图点击推进后刷新地图、节点、场景占位、choices、变量
[x] 地图点击推进后按节点类型给予默认收益
[x] 三变量保留：军功 / 清望 / 旧案线索
[x] 普通 choices 按各自 delta 修改三变量
[x] 场景信息分层展示：_format_scene_text 按句切分为 bullet
[x] 战斗桥接：请求战斗 / 视为胜利继续 / node_id / encounter_id
[x] 请求战斗已升级为跳转 MainVisual.tscn
[x] 从 MainVisual 返回后可消费 battle result
[x] win 后自动给予战斗收益，并推进到下一节点
[x] lose / draw 当前只返回当前节点并提示，不做复杂惩罚
[x] 结局与重开闭环
[x] 收益与推进入口已收口：_apply_choice_delta / _apply_default_map_reward / _advance_to_node
[x] UI 分层完成：map_buttons_box / combat_buttons_box / choices_box
[x] 下方操作区已改为 ScrollContainer，避免选项被挤出屏幕
[x] 最小图片显示：TextureRect + ResourceLoader.exists
[x] 视觉资源路径已切到 SVG 占位资源
[x] 视觉资源诊断：visual_debug_label 显示 path / exists / type / 状态
```

对应近期提交：

```text
07a22f47c6f3bdb693cc082d0f86fd5f4e6d9c9f  Add one-way jump from narrative demo to battle scene
bfe1aeea444afc112740df0c27557557ffdb2693  Make narrative action area scrollable
c139ebfc4504ffe1be72f73f2c3d168028151e34  Consume battle result when returning to narrative demo
7311d8321ed6f02be3700c4bbafdf96a624bbcf1  Connect prologue master rescue to battle
21a41d6423edf8acebec65801fd4403a6041c9f4  Add career selection and player growth to narrative demo
```

---

### 2.3 Narrative Battle Context

文件：

```text
scripts/narrative_battle_context.gd
```

作用：

```text
作为叙事与战斗之间的轻量上下文，记录并持久化：
encounter_id
source_node_id
source_scene
return_after_battle
last_result
result_ready
player profile
```

当前行为：

```text
set_request()
→ 先拉取 Engine metadata
→ 写入 encounter/source/result 状态
→ 保留玩家数据
→ 写回 Engine metadata

set_result()
→ 先从 Engine metadata 拉取上下文与玩家数据
→ 写入 last_result / result_ready
→ 如果上下文缺失，source_node_id 默认 beach_ambush、source_scene 默认 NarrativeDemo、encounter_id 默认 enc_fallback
→ 再写回 Engine metadata

clear()
→ 只清空战斗上下文
→ 保留玩家数据

clear_player_profile()
→ 重开时清空玩家职业与成长数据
```

新增玩家数据能力：

```text
set_player_profile(profile)
→ 初始化玩家数据

has_player_profile()
→ 判断是否已有出山职业

get_player_profile()
→ 返回职业、武器、HP、势、武境、胜场

apply_player_growth(source, hp_gain, posture_gain, martial_gain, heal_full)
→ 推动玩家成长

player_profile_debug_text()
→ 输出玩家数据摘要
```

当前玩家职业：

```text
长枪武官
→ role=spearman
→ weapon=长枪
→ HP=38/38
→ 势=6/10
→ 武境=1
→ 特点：稳扎稳打，血量较高，适合长枪压步、抢势、控距离

腰刀武官
→ role=blademaster
→ weapon=腰刀
→ HP=34/34
→ 势=7/10
→ 武境=1
→ 特点：节奏更快，势更高，适合格挡反击、突进斩杀
```

当前成长规则：

```text
战斗胜利
→ 胜场 +1
→ 最大 HP +2
→ 武境 +1
→ HP 回满
→ 势回满

旧物默认收益
→ 势上限 +1
```

接战映射与玩家职业关系：

```text
序章师父救场战
→ 固定 player_role=blademaster，代表玩家操控师父

进入出山后的正式战斗
→ get_battle_mapping() 优先使用当前玩家 player_role
→ 敌人仍按 encounter_id 使用 enemy_config
```

新增 V3 敌人配置能力：

```text
get_battle_mapping()
→ 根据 encounter_id 返回推荐接战配置与 enemy_config
→ 正式战斗会叠加当前玩家职业和玩家数据

get_enemy_config()
→ 返回当前 encounter 的敌人配置

battle_mapping_debug_text()
→ 输出当前推荐映射 + 玩家数据

enemy_config_debug_text()
→ 输出敌人配置摘要，供 MainVisual 诊断面板展示

enemy_config_full_text()
→ 输出玩家数据 + 完整敌人配置，供 MainVisual 顶部横条强显示
```

当前映射与敌人配置：

```text
enc_prologue_master_rescue：序章救场 / 袭村倭寇刀手
→ player_role=blademaster
→ enemy_role=enemy_blademaster
→ enemy_family=blademaster
→ difficulty=tutorial_elite
→ enemy_id=enemy_blademaster_prologue_raider
→ display_name=袭村倭寇刀手
→ weapon=倭刀
→ max_hp=24
→ max_posture=10
→ start_posture=3
→ intent_style=tutorial_victim
→ behavior_tags=教学 / 低血量 / 可速杀 / 临死线索
→ reward=军功+0 / 清望+0 / 旧案线索+1

enc_beach_ambush：海边伏击 / 敌方枪手
→ player_role=当前玩家职业
→ enemy_role=enemy_spearman
→ enemy_family=spearman
→ difficulty=normal
→ enemy_id=enemy_spearman_beach_ambush
→ display_name=敌方枪手
→ weapon=长枪
→ max_hp=26
→ max_posture=10
→ start_posture=4
→ intent_style=poke_pressure
→ behavior_tags=试探 / 抢势 / 突刺 / 低防御
→ reward=军功+1 / 清望+0 / 旧案线索+1

enc_transport_officer：失械案押运官 / 敌方刀客
→ player_role=当前玩家职业
→ enemy_role=enemy_blademaster
→ enemy_family=blademaster
→ difficulty=elite
→ enemy_id=enemy_blademaster_transport_officer
→ display_name=失械案押运官
→ weapon=腰刀
→ max_hp=34
→ max_posture=10
→ start_posture=5
→ intent_style=counter_break
→ behavior_tags=架刀 / 反击 / 破防 / 压迫
→ reward=军功+1 / 清望+1 / 旧案线索+2

enc_wakou_boss：破船 Boss / 小股倭寇首领
→ player_role=当前玩家职业
→ enemy_role=enemy_blademaster
→ enemy_family=blademaster
→ difficulty=boss
→ enemy_id=enemy_blademaster_wakou_leader
→ display_name=小股倭寇首领
→ weapon=倭刀
→ max_hp=42
→ max_posture=10
→ start_posture=6
→ intent_style=boss_feint_burst
→ behavior_tags=虚招 / 抢势 / 连斩 / 临死线索
→ reward=军功+2 / 清望+0 / 旧案线索+2
```

对应提交：

```text
bc38e66a4e06daa3af46376900401c4fa4090ea2  Add battle result state to narrative context
a7df5dcc37c44f52e22564322e47b0d96b3542ec  Persist narrative battle context in metadata
b7d59ab944fdea36ea78a25cc76536f520a6bebf  Add narrative encounter battle mapping
1ed1e75b11dc4c160783159cd26e8c0f30b6b7ce  Add enemy configs for narrative MVP encounters
d614ee15156e17bc9b52fe306478b0f0b37fe6de  Add prologue master rescue encounter config
d6b0fdb922c4509258f990ee2a03aeeef5a52c7f  Persist player career profile for narrative battles
```

---

### 2.4 MainVisual 叙事上下文、敌人配置与返回剧情控件

文件：

```text
scripts/battle_controller_visual_narrative_context.gd
```

实现方式：

```text
extends res://scripts/battle_controller_visual_break_preview.gd
_ready() 中先 super._ready()
无论 NarrativeBattleContext.has_request() 是否为 true，都创建 CanvasLayer，layer=100
CanvasLayer 顶部横条显示：
- 玩家数据
- 完整敌人详细配置
CanvasLayer 右上角显示：
- 关卡信息 / 推荐接战信息
- 叙事上下文诊断
- 接战映射诊断
- 敌人配置摘要
- 战斗结果诊断
- 按推荐接敌按钮
- 返回剧情按钮
```

当前结果规则：

```text
player.hp > 0 and enemy.hp <= 0 → narrative_result=win
player.hp <= 0 and enemy.hp > 0 → narrative_result=lose
player.hp <= 0 and enemy.hp <= 0 → narrative_result=draw
player/enemy 不可用或尚未结算时点击返回 → win 保底
```

新增 V3 过渡能力：

```text
EnemyConfigTopStrip
→ 显示 NarrativeBattleContext.enemy_config_full_text()
→ 位于 MainVisual 顶部，避免右上角面板空间不足导致看不到详细配置

EnemyConfigDebugLabel
→ 显示 NarrativeBattleContext.enemy_config_debug_text()
→ 当前仅作为配置验收展示，不直接覆盖战斗实例

RecommendedBattleButton
→ 文案：“按推荐接敌”
→ 点击后读取 NarrativeBattleContext.get_battle_mapping().player_role
→ 先写入 player_role_id
→ 尝试按安全候选函数名调用现有角色选择/开战入口
→ 若未匹配入口，不报错，只提示继续使用原角色选择按钮
```

当前候选入口：

```text
一参候选：
_on_role_selected(role_id)
_select_role(role_id)
_choose_role(role_id)
_pick_role(role_id)
_start_battle(role_id)
_begin_battle(role_id)
_start_session(role_id)
_begin_session(role_id)
_start_run(role_id)

零参候选：
_confirm_role_selection()
_confirm_role_pick()
_start_battle()
_begin_battle()
_start_session()
_begin_session()
_start_run()
```

防护：

```text
调用前用 get_method_list() 检查方法名和参数数量；
不直接 call 不存在方法；
未匹配时只写 player_role_id 并提示，不影响原手动入口。
```

对应提交：

```text
97bffadb05c0ee994edb27597319e22c251ef645  Add narrative context wrapper for MainVisual
02301584ac14d56483a2f9c6d1c3052abd40dbea  Use narrative context wrapper for MainVisual
a4777fd2b960aa63e366db88eba5b417b62f09ae  Add battle result diagnostics to narrative wrapper
6f68afe348bb66a3ecd052bcd1d5ccd08f48dec1  Fix battle state machine name collision in narrative wrapper
59ec540fedcd2b1160bad2aa8b891acf9bcd0700  Make continue narrative button robust after hp zero
fb13aad67c3e3a3c3b50c3a8ed3b5aba3f3efec0  Add always visible return narrative control
fbdbb8a7434e51e088e74741efb6e421136587fe  Show return narrative control unconditionally in MainVisual
01392a2a1ab57d537f189d7c198d2899bea4c381  Show narrative encounter mapping in battle debug panel
dbca1c0e0c01f98c641b8ef9263b58fd3802aa09  Make encounter mapping visible in MainVisual panel
608afa2569611e01bc212455361cbf25876aaafd  Add recommended battle entry control
e7119878ed82301534e7e8227ece54e17fc579ae  Show enemy config summary in narrative battle panel
3cc4eff045f2302558e2461481302d7ca38c016d  Add top enemy config strip in MainVisual
```

验收状态：

```text
[x] MainVisual 右上角已出现返回剧情按钮
[x] 返回剧情闭环已验收通过
[x] 关卡信息 / 接战映射可见性已验收通过
[ ] 出山职业选择仍需 Web 验收
[ ] 玩家数据初始化仍需 Web 验收
[ ] 后续战斗沿用玩家数据仍需 Web 验收
[ ] 战斗胜利后玩家成长仍需 Web 验收
[ ] 顶部敌人详细配置横条仍需 Web 验收
[ ] 序章师父救场战仍需 Web 验收
[ ] “按推荐接敌”按钮仍需 Web 验收
```

约束：

```text
不强制绕过角色选择
不强制自动换敌人
不改战斗规则
不改 BattleStateMachine
只做推荐接敌入口、玩家数据、敌人配置展示与可回退调用
```

---

## 3. 当前 UI 修复说明

### 3.1 NarrativeDemo 下方 UI

问题：

```text
下方 UI 显示不全，尤其是“叙事选择”区域容易被挤出屏幕。
```

修复：

```text
map_buttons_box / combat_buttons_box / choices_box 统一放入 action_scroll: ScrollContainer
action_scroll 设置 SIZE_EXPAND_FILL
操作区高度保底 250
每次刷新时 action_scroll.scroll_vertical = 0
```

---

## 4. 当前视觉显示规则

节点现在配置：

```text
visual_path
```

规则：

```text
visual_path 为空 → 显示文本占位；诊断 path=空 / 状态=文本占位
ResourceLoader.exists(path) 为 false → 显示文本占位；诊断 exists=false
资源存在且是 Texture2D → TextureRect 显示图片；诊断 exists=true / type=Texture2D / 状态=已显示
资源存在但不是 Texture2D → 显示错误占位文本；诊断 exists=true / type=<class> / 状态=非 Texture2D
```

---

## 5. 当前收益与推进规则

### 5.1 普通选择按钮

```text
普通 choice 点击
→ 修改军功 / 清望 / 旧案线索
→ 后续可扩展为影响玩家状态
→ 推进到下一节点
```

### 5.2 地图点击按钮

```text
地图按钮点击
→ 当前节点：只提示，不推进
→ 已走节点：只提示，不推进
→ 未开放节点：只提示，不推进
→ 可前往节点：按节点类型给予默认收益并推进
```

### 5.3 职业选择

```text
十年后：该出山了
→ 显示长枪武官 / 腰刀武官
→ 点击后 NarrativeBattleContext.set_player_profile()
→ 初始化职业、武器、HP、势、武境、胜场
→ 进入军令巡海
```

### 5.4 战斗结果返回

```text
MainVisual 返回 NarrativeDemo 后：
如果 source_node_id == prologue_master_rescue：
	回到序章 step=8，即“敌人临死：军……”
	win 时旧案线索 +1
	显示“序章战斗胜利：师父斩敌，敌人临死吐出旧案线索。”

如果 last_result == win：
	根据原战斗节点类型给予战斗收益
	玩家数据成长：胜场 +1，最大 HP +2，武境 +1，HP/势回满
	自动推进到下一节点
如果 last_result == lose：
	停留当前节点，仅提示失败
如果 last_result == draw：
	停留当前节点，仅提示同归于尽
如果上下文丢失但返回成功：
	source_node_id 默认 beach_ambush
	last_result 默认 win
	优先保证 MVP 闭环成立
```

---

## 6. 真实战斗接入结论

### 6.1 MainVisual 当前入口

已核查 `scenes/MainVisual.tscn`：

```text
[ext_resource type="Script" path="res://scripts/battle_controller_visual_narrative_context.gd" id="1_visual"]
script = ExtResource("1_visual")
```

结论：

```text
MainVisual 确实挂载 wrapper；按钮不出现不是 MainVisual.tscn 挂载错误导致。
```

该 wrapper 继承：

```text
res://scripts/battle_controller_visual_break_preview.gd
```

原始战斗继承链路仍为：

```text
battle_controller_visual_break_preview.gd
→ battle_controller_visual_resolver_preview.gd
→ battle_controller_visual_responsive_ui.gd
→ battle_controller_visual_cached_ui.gd
→ battle_controller_visual_ui.gd
→ battle_controller_demo_visual.gd
→ battle_controller_core.gd
```

### 6.2 Battle Core 当前启动方式

`battle_controller_core.gd` 的 `_ready()` 当前流程为：

```text
_build_catalog()
_build_ui()
state_machine.reset_for_session()
_show_role_selection()
```

当前判断：

```text
角色选择和战斗创建入口还没有被稳定定位到可安全覆盖的函数。
已先通过“按推荐接敌”按钮做反射式安全尝试：有匹配入口就调用；没有就回退到原手动选择入口。
```

### 6.3 胜负结算点

文件：

```text
scripts/battle_state_machine.gd
```

关键函数：

```text
resolve_intent(intent, actor, target)
finish_round(player, enemy)
```

结论：

```text
HP 归零发生在 resolve_intent()
phase 切到 RESULT 发生在 finish_round()
但实际 UI 链路中 phase 不一定稳定停留在 RESULT，因此当前 wrapper 使用 CanvasLayer 无条件返回控件保证 MVP 闭环优先成立。
```

---

## 7. 当前仍需推进

```text
[x] Web 验收：打开 MainVisual 后，右上角无条件出现“返回剧情”按钮
[x] Web 验收：点击“返回剧情”能返回 NarrativeDemo
[x] Web 验收：返回后 NarrativeDemo 自动推进到下一节点
[x] Web 验收：MainVisual 原有角色选择入口不受影响
[x] Web 验收：NarrativeDemo 下方选项完整显示 / 可滚动
[x] Web 验收：MainVisual 右上角显示关卡信息 / encounter_id 接战映射诊断
[ ] Web 验收：序章“十年后：该出山了。”显示职业选择
[ ] Web 验收：选择长枪武官后初始化 spearman 玩家数据
[ ] Web 验收：选择腰刀武官后初始化 blademaster 玩家数据
[ ] Web 验收：后续战斗 MainVisual 顶部横条显示玩家数据 + 敌人详细配置
[ ] Web 验收：战斗胜利后玩家数据成长
[ ] Web 验收：MainVisual 顶部显示敌人详细配置横条
[ ] Web 验收：序章师父救场段出现“请求序章战斗：师父救场”按钮
[ ] Web 验收：序章师父救场战返回后继续到“敌人临死：军……”
[ ] Web 验收：“按推荐接敌”按钮是否出现
[ ] Web 验收：点击“按推荐接敌”是否能自动进入推荐职业，或至少提示回退到手动选择
[x] 美术管线口径已切换为正式 PNG 运行资源；`art_reference/generated` 参考图不直接挂运行
[ ] 若旧 SVG 仍出现在正式场景 / 角色 / 道具路径中，优先替换为 `assets/**/*.png`
[ ] V3：encounter_id → enemy/fighter 自动配置
[ ] V4：失败/平局叙事分支
```

---

## 8. 下一刀建议：Web 验收职业选择与玩家数据贯穿

目标：

```text
确认“十年后出山职业选择 → 玩家数据初始化 → 后续战斗沿用并成长”成立。
```

验收标准：

```text
[ ] 序章推进到“十年后：该出山了。”时，不直接进入地图，而是出现：
	长枪武官｜长枪｜HP 38｜势 6/10
	腰刀武官｜腰刀｜HP 34｜势 7/10

[ ] 选择长枪武官后，进入“军令巡海”，变量栏显示：
	玩家数据=spearman｜职业=长枪武官｜武器=长枪｜HP=38/38｜势=6/10｜武境=1｜胜场=0

[ ] 选择腰刀武官后，进入“军令巡海”，变量栏显示：
	玩家数据=blademaster｜职业=腰刀武官｜武器=腰刀｜HP=34/34｜势=7/10｜武境=1｜胜场=0

[ ] 请求 beach_ambush 战斗后，MainVisual 顶部横条显示玩家数据 + 敌人详细配置

[ ] 战斗返回 win 后，玩家数据成长：
	胜场 +1
	最大 HP +2
	武境 +1
	HP/势回满

[ ] 返回剧情闭环不受影响
[ ] Web 构建稳定
```

---

## 9. 后续路线

### Step 1：Web 验收职业选择与玩家数据贯穿

```text
确认职业选择、初始化、战斗沿用、战后成长都成立。
```

### Step 2：Web 验收顶部敌人配置横条与序章师父救场战

```text
确认详细配置可见，序章战斗也纳入剧情—战斗—剧情闭环。
```

### Step 3：Web 验收“按推荐接敌”按钮

```text
确认推荐接敌按钮可见、可点、不破坏原入口。
```

### Step 4：固化 player_role 自动选择

```text
优先只自动选择玩家职业，不改敌人逻辑。
```

### Step 5：encounter_id → enemy/fighter 自动配置

```text
只映射到已有 spearman / blademaster，不新增复杂敌人体系。
仍不改战斗规则，只做启动参数接入。
```

### Step 6：失败 / 平局叙事分支

```text
先轻量处理失败、平局，不做复杂惩罚系统。
```

---

## 10. 给 Codex 的下一步指令

```text
请继续在安全线推进，不要恢复 scripts/narrative/* 旧复杂链路。当前新增“出山职业选择 + 玩家数据初始化与成长”：NarrativeDemo 在“十年后：该出山了。”显示长枪武官 / 腰刀武官，选择后调用 NarrativeBattleContext.set_player_profile() 初始化职业、武器、HP、势、武境、胜场；NarrativeBattleContext 通过 Engine metadata 持久化玩家数据，clear() 只清战斗上下文，clear_player_profile() 才清玩家档案；正式战斗 get_battle_mapping() 优先使用当前玩家职业，MainVisual 顶部横条显示玩家数据 + 敌人详细配置；战斗 win 返回后玩家成长为胜场+1、最大HP+2、武境+1、HP/势回满。下一步请 Web 回归验收职业选择、变量栏玩家数据、进入战斗后的顶部玩家数据，以及战斗返回后的成长是否正确。不要改 BattleStateMachine，不要强制绕过原角色选择入口。
```

---

## 11. 当前一句话结论

```text
“十年后出山”已改为职业选择，玩家单局数据已初始化并持久化；后续战斗映射、顶部横条与战后成长都会沿用这份数据。
```
