# 《大明之沧海嘀鸣》UI 管线总文档

本文档是当前 UI / 视觉战斗界面 / Web UI 性能收敛的活跃入口。旧文档 `ui_architecture_refactor.md`、`wuxia_battle_ui_godot_design.md`、`BATTLE_PRESENTATION_LAYER.md` 中仍保留历史细节；若与本文档、`docs/BATTLE.md` 或运行代码冲突，以本文档和当前代码为准。

## 1. 当前入口

运行入口：

```text
scenes/Main.tscn
→ 桌面：scenes/MainDesktop.tscn
→ Web：scenes/MainWeb.tscn
→ 战斗测试 / 剧情战斗：scenes/MainVisual.tscn
```

`MainVisual.tscn` 当前挂载：

```text
scripts/battle_controller_visual_story_return.gd
```

视觉控制器继承链：

```text
battle_controller_visual_story_return.gd
→ battle_controller_visual_settlement_mode.gd
→ battle_controller_visual_preview_position_guard.gd
→ battle_controller_visual_presentation_mode_aware.gd
→ battle_controller_visual_presentation_stepwise.gd
→ battle_controller_visual_presentation.gd
→ battle_controller_visual_scene_manifest.gd
→ battle_controller_visual_narrative_formal.gd
→ battle_controller_visual_narrative_context.gd
→ battle_controller_visual_break_preview.gd
→ battle_controller_visual_resolver_preview.gd
→ battle_controller_visual_hot_tuning.gd
→ battle_controller_visual_tuning_panel.gd
→ battle_controller_visual_preview_checked.gd
→ battle_controller_visual_responsive_ui.gd
→ battle_controller_visual_cached_ui.gd
→ battle_controller_visual_ui.gd
→ battle_controller_demo_visual.gd
→ battle_controller_core.gd
```

## 2. 职责边界

| 层 / 文件 | 职责 |
|---|---|
| `battle_controller_core.gd` | 战斗流程、状态转换、卡牌消耗、回合结束、结算入口；不要继续扩大 UI scaffold |
| `battle_controller_text_ui.gd` | 字符版 / 调试版 UI，完整文本状态和文本预览 |
| `battle_controller_demo_visual.gd` | 视觉版基础场景构建，舞台、HUD、底部区、弹窗基础节点 |
| `battle_controller_visual_ui.gd` | 视觉 UI 主刷新层，HUD、手牌、详情、预览、格位、角色定位 |
| `battle_controller_visual_cached_ui.gd` | UI 缓存、签名刷新、ActorRuntime 接入、旧预览 fallback |
| `battle_controller_visual_resolver_preview.gd` | 正式效果预览，以顺序模拟和真实 target stance 为准 |
| `battle_controller_visual_presentation*.gd` | 只消费结算结果做表现，不制造战斗结果 |
| `battle_controller_visual_settlement_mode.gd` | 战斗测试列表、剧情遭遇选择、对称 / 反应式模式入口 |
| `battle_controller_visual_story_return.gd` | 结算弹窗、剧情 / 战斗测试回流、压力规则 |
| `scripts/visual/*` | 可复用视觉 helper：皮肤、舞台几何、HUD 文本、Actor 动画、FX 池 |

实践规则：

- 改战斗规则：优先看 `battle_controller_core.gd`、`battle_state_machine.gd`、`combat_resolver.gd`。
- 改视觉布局 / HUD / 舞台格：优先看 `battle_controller_demo_visual.gd` 和 `battle_controller_visual_ui.gd`。
- 改动态效果预览：优先看 `battle_controller_visual_resolver_preview.gd`。
- 改攻击 / 受击 / 死亡 / 逐格移动演出：优先看 `battle_controller_visual_presentation_stepwise.gd`。
- 不为绕开大文件修改继续增加长期 wrapper；做局部 patch，完成后尽量合层。

## 3. 画面层级

视觉战斗根节点是一个 `Control`。当前层级口径：

```text
BattleControllerVisualUI
├── stage_layer                 战斗舞台底层
│   ├── background_texture / stage_scene_clip
│   ├── stage_area_frame
│   ├── range_overlay_layer
│   ├── stage_grid_box
│   ├── stage_slot_label_box
│   ├── player_sprite / enemy_sprite
│   ├── player_intent_bubble / enemy_intent_bubble
│   └── center_fx_layer
├── top_hud                     顶部头像、血量、势豆
├── bottom_backdrop
├── bottom_root                 底部操作区
├── screen_flash
├── overlay_scrim / overlay_panel
└── battle_result_scrim / battle_result_panel
```

层级规则：

- `stage_layer` 永远不能盖住顶部 HUD、底部操作区、弹窗。
- 结算弹窗使用独立 `battle_result_*` 节点，不和战斗测试列表 / 普通弹窗共用。
- 普通弹窗和结算弹窗都必须在打开时 `move_to_front()`。
- debug 面板默认关闭，通过 `F10` 切换。

## 4. 舞台与站位

当前战斗舞台是 9 个横向格位：

```text
一 二 三 四 五 六 七 八 九
```

关键常量位于 `battle_controller_demo_visual.gd`：

```text
GRID_SLOT_COUNT = 9
GRID_SLOT_WIDTH = 126
GRID_SLOT_HEIGHT = 48
GRID_SLOT_GAP = 6
GRID_STAGE_Y = 468
STAGE_GROUND_Y = 510
```

站位口径：

- 格子位置固定，不随角色高度变化。
- 格子高亮、圆圈高亮和角色落脚点必须对齐到同一站位格高度。
- 站位中文数字显示在格子中心，作为半透明辅助信息。
- 角色贴图定位使用 actor meta 的 `foot_anchor`，不是整张图中心。
- 长枪等宽帧角色必须使用镜像后的 foot anchor，避免左右朝向漂移。

## 5. HUD 与底部操作区

顶部 HUD：

- 左侧玩家、右侧敌人。
- 血条绑定真实 `fighter.hp / fighter.data.max_hp`。
- 势豆绑定真实 `fighter.momentum / fighter.data.max_momentum`。
- 战斗开始时必须按满血刷新，不允许沿用旧宽度缓存。

底部操作区：

```text
bottom_root
├── control_bar
│   ├── 重选招式
│   ├── 确认出招
│   └── node_buttons_box
└── bottom_panels
    ├── hand_panel
    ├── card_detail_panel
    └── effect_preview_panel
```

布局口径：

- 招式区约 1/2 宽度。
- 招式详情约 1/4 宽度。
- 效果预览约 1/4 宽度。
- 底部区有独立深色底板，舞台背景、角色、范围层不能侵入。
- 文字必须在按钮、卡牌、面板内稳定显示，不允许遮挡或溢出到相邻区。

## 6. 预览管线

正式效果预览来源：

```text
battle_controller_visual_resolver_preview.gd
→ _ordered_preview_simulation()
→ _effect_preview_text()
```

一致性要求：

- 玩家看到的目标格位 = 真实结算使用的格位 = 演出先移动到的格位。
- 玩家看到的目标朝向 = 真实结算使用的朝向 = 演出出招前的朝向。
- `cached_ui` 中的旧预览只保留为 legacy fallback，不能覆盖正式预览。
- UI 层不重新发明结算规则，只消费 resolver / state machine 给出的模拟结果。

目标格位 / 朝向输入：

| 操作 | 目标格位 | 目标朝向 |
|---|---|---|
| 回合开始不操作 | 当前格 | 当前实际朝向 |
| 点击原地格 | 当前格 | 当前朝向反转 |
| 点击其他合法格 | 新格 | 当前实际朝向 |
| 再点该目标格 | 新格 | 目标朝向反转 |
| 点击非法格 | 不变 | 不变 |

## 7. 演出管线

演出层只消费真实结算结果。当前顺序：

```text
目标格位逐格移动
→ 必要时事件驱动转身
→ 攻击 / 防御 / 聚势动作
→ 刀光 / 枪线 / 火器 / 命中 / 未中 / 破势 FX
→ 受击动画与命中停顿
→ 真实结果飘字
→ 招式效果位移
→ 死亡反馈
→ 结算弹窗
```

死亡表现口径：

- 被击杀者先完整播放受击表现。
- 受击表现结束后停顿 `0.2s`。
- 再执行死亡下沉淡出并隐藏。
- 结算弹窗必须等 presentation busy 结束后再出现。
- 死亡后 `_refresh_ui()` 可以继续隐藏 dead actor，但不能抢在死亡演出前隐藏。

## 8. 刷新与缓存

视觉层当前仍保留 `_process()` 兜底刷新，但已经用签名和缓存降低重复写 UI。

已有收敛项：

- 舞台格子 / 攻击范围签名。
- 角色站位 / 朝向签名。
- HUD 条和势豆签名。
- 意图气泡签名。
- 手牌区签名。
- 节点按钮区签名。
- 攻击范围梯形节点复用。
- 主要打击 FX 池化。
- 弹窗按钮池化。
- 普通按钮样式一次性套用。

相关 helper：

| 文件 | 职责 |
|---|---|
| `scripts/visual/battle_skin.gd` | texture / style / button skin 缓存 |
| `scripts/visual/battle_stage_view.gd` | 舞台几何、格位、范围预览 math |
| `scripts/visual/battle_hud_view.gd` | HUD 文本、卡牌摘要、效果描述 |
| `scripts/visual/battle_fx_pool.gd` | 可复用 FX 节点池 |
| `scripts/visual/actor_animation_*` | 角色动作 meta、runtime、hit frame 信号 |

后续方向：

- 继续把 `_process()` 兜底刷新收敛到事件驱动。
- 继续把 `battle_controller_demo_visual.gd` 中可复用视图拆到 `scripts/visual/*`。
- 不在 `core` 里新增 UI ownership。

## 9. 弹窗与回流

弹窗分两类：

| 类型 | 节点 | 用途 |
|---|---|---|
| 普通 overlay | `overlay_scrim / overlay_panel / overlay_actions` | 战斗测试列表、牌库、摘要、选择类弹窗 |
| 结算 overlay | `battle_result_scrim / battle_result_panel / battle_result_actions` | 战斗胜利 / 战斗失败确认 |

战斗测试回流：

- 从战斗测试列表进入的战斗，结算确认后回到战斗测试选择界面。
- 战斗测试选择界面顶部有“返回主菜单”按钮。
- 从主菜单进入战斗测试前清空剧情战斗请求，避免残留剧情上下文串线。

剧情回流：

- 从剧情节点进入的战斗，结算确认后写入 `NarrativeBattleContext` 结果并返回来源剧情场景。
- `override_player_profile=false` 的剧情战可让玩家槽位使用剧情角色，例如序章师父救场。

## 10. Debug 与调参

默认状态：

- 战斗场景 debug 面板默认关闭。
- `F10` 切换稳定 debug 面板。
- `F8` 切换对称 / 反应式结算模式。
- `Z` 撤销当前移动草稿。

调参入口：

- 热调面板：`battle_controller_visual_hot_tuning.gd`。
- 稳定 debug 面板：`battle_controller_visual_scene_manifest.gd`。
- 调参只应改变表现参数或当前测试上下文，不应绕过正式结算。

## 11. Web UI 口径

Web 运行入口：

```text
scenes/MainWeb.tscn
→ scripts/web_runtime_launcher.gd
→ scenes/MainVisual.tscn
```

Web 约束：

- 避免高频重建 Control 节点。
- 避免高频设置 theme override。
- 大图源放在 `art_reference/`，运行资源只引用 `assets/`。
- `build/`、`dist/`、`.godot/` 不作为源文件。
- Web 构建问题记录在 `docs/web_build_known_issues.md`。

## 12. 验收命令

基础加载：

```bash
godot --headless --path . --quit
```

战斗测试回流：

```bash
godot --headless --path . --script res://tools/smoke_battle_test_return.gd
```

数值配置：

```bash
godot --headless --path . --script res://tools/smoke_battle_number_profiles.gd
```

Web bundle：

```bash
./tools/build_web_bundle.sh
```

Godot headless smoke 退出时可能出现已知 RID/resource leak 提示；只要脚本结果为 OK 且退出码为 0，不作为本 UI 管线的阻塞失败。

## 13. 旧文档归属

| 文档 | 现在用途 |
|---|---|
| `docs/ui_architecture_refactor.md` | 早期 UI 拆层笔记，已被本文档吸收 |
| `docs/wuxia_battle_ui_godot_design.md` | 早期视觉布局细节附录，标题和部分文案已过时 |
| `docs/BATTLE_PRESENTATION_LAYER.md` | 演出层历史 phase 和细节附录 |
| `docs/web_refactor_progress.md` | Web 化阶段进度记录，不作为 UI 架构主入口 |
| `docs/web_build_known_issues.md` | Web 已知问题清单 |
