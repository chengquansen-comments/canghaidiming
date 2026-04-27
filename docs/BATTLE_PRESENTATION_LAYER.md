# 《大明之沧海嘀鸣》战斗演出层说明

> 版本：v1.7  
> 分支：`main`  
> 状态：Phase 1 已验收通过；Phase 2 / 3 / 5 / 6 / 7 / 8 / 9 / 10 / 11 / 12 / 12.5 / 12.6 / 12.7 / 12.8 / 12.9 已接入，待统一本地验收；Phase 13.0 已完成 helper 抽出，主演出层接入待本地 patch  
> 入口场景：`scenes/MainVisual.tscn`  
> 当前场景入口脚本：`scripts/battle_controller_visual_story_return.gd`

---

## 1. 当前目标

当前战斗是回合制卡牌单局，不是实时动作游戏。演出层目标是让结算结果有“武打反馈”，而不是重写动作系统。

当前完整表现链路：

```text
选择目标格位 / 目标朝向
→ 招式范围按目标格位 + 目标朝向预览
→ 确认招式
→ 真实结算先提交 target_position / target_facing
→ 演出层先逐格移动到目标格位
→ 若目标朝向变化，则先转身到目标朝向
→ 角色前冲 / 水墨枪线 / 水墨刀光 / 火器闪光与烟雾
→ 目标受击或落空提示
→ 防御墨盾 / 聚势气纹
→ 真实结算飘字
→ 破势墨裂 / 命中停顿
→ 招式造成的击退 / 拉近 / 进身 / 后撤等效果位移逐格表现
→ 若事件要求转身，则播放转身
→ 死亡反馈
```

核心原则：

```text
战斗结算决定结果；演出层只消费结果、意图、卡牌信息、最终格位和事件触发的朝向变化。
不会仅因敌我相对位置变化自动转身。
移动目标格位与目标朝向是两个独立选择状态。
预览、真实结算、演出必须使用同一套 target_position / target_facing。
效果预览只以 resolver_preview 的顺序模拟为正式来源。
```

---

## 2. 当前继承链路

`MainVisual.tscn` 当前挂载：

```text
res://scripts/battle_controller_visual_story_return.gd
```

完整继承链路：

```text
battle_controller_visual_story_return.gd
→ battle_controller_visual_settlement_mode.gd
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

分工：

| 层 | 职责 |
|---|---|
| `story_return` | 剧情战斗结束后返回剧情选择；压力规则 |
| `settlement_mode` | 剧情遭遇选择；对称 / 反应式结算切换 |
| `presentation_stepwise` | 当前主演出层：逐格移动、事件驱动转身、目标格位/目标朝向输入、死亡刷新保护、SVG FX 资产化与调参常量、目标站位与效果位移分段演出 |
| `presentation` | 攻击、受击、命中反馈、真实结果飘字、死亡、基础落位 |
| `resolver_preview` | 正式效果预览：按 target stance 推算范围、顺序结算和最终格位，并输出破势/死亡/背击快照 |
| `cached_ui` | UI 缓存、格位刷新、ActorRuntime；旧效果预览已降级为 legacy fallback |
| `battle_target_selection` | Phase 13.0 新增 helper：目标格位/目标朝向选择纯规则；待接入主演出层 |
| `battle_facing_rules` | Phase 13.0 新增 helper：朝向、背击、转身招式纯规则；待接入主演出层 |
| `battle_state_machine` | 真实结算；提交 intent target stance；不再默认自动 face_target |

---

## 3. 已实现阶段

| 阶段 | 内容 | 状态 |
|---|---|---|
| Phase 1 | 攻击前冲、回撤、刀光、枪影、受击、飘字、死亡 | `DONE / PASSED` |
| Phase 2 | 结算后旧格位视觉起点保持、真实格位平滑落位 | `DONE / SUPERSEDED_BY_PHASE_10` |
| Phase 3 | 使用 `_ordered_preview_simulation()` 显示真实 damage / break / gain / range | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 5 | 命中停顿、擦中弱反馈、破势墨裂、火器/终结强化 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 6 | 火器、破势、未中 FX 资产化 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 7 | 刀光、枪线、命中爆点 FX 资产化 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 8 | 格挡墨盾、聚势气纹、火器烟雾 FX 资产化 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 9 | FX 尺寸、透明度、层级、偏移、淡出时间集中成常量 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 10 | 结算后位置变化从“一次滑动”改为“一格一格移动” | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 11 | 事件驱动转身：背击受击、行动目标反向、招式自带转身 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 12 | 目标格位 / 目标朝向解耦；范围预览按目标状态推算 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 12.5 | 预览 / 真实结算 / 演出统一提交 target_position + target_facing；移除默认自动面向；修复 FX stage center 编译风险 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 12.6 | 输入合法性；破势/死亡/背击快照；死亡淡出不复现 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 12.7 | 合层整理：删除临时 `presentation_guarded` wrapper；死亡刷新保护合回 `presentation_stepwise`；反应式预览不再自动面向敌人 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 12.8 | 清理旧效果预览入口：`cached_ui.gd` 的旧 `_effect_preview_text()` 降级为 `_legacy_effect_preview_text()`，正式效果预览只由 `resolver_preview.gd` 提供 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 12.9 | 合并 SVG FX wrapper：删除 `presentation_assets.gd`，SVG FX 常量与方法合入 `presentation_stepwise.gd`，继承链减少一层 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 13.0 | 抽出目标选择与朝向规则 helper：新增 `battle_target_selection.gd`、`battle_facing_rules.gd`；因 `presentation_stepwise.gd` 文件较大，主演出层局部接入建议使用本地 patch 工具完成 | `PARTIAL / HELPER_READY` |

---

## 4. Phase 10：逐格移动规则

```text
不要 old_slot → new_slot 一次滑过去；
要 old_slot → 第1格 → 第2格 → ... → new_slot，把过程展现清楚。
```

实现文件：

```text
scripts/battle_controller_visual_presentation_stepwise.gd
```

当前规则：

```text
1. 表现层不直接决定真实 position。
2. 真实结算完成后，表现层用 presentation offset 把角色视觉放回需要表现的旧位置。
3. 需要移动时，按格逐段移动。
4. 每格移动都有轻微上抬和短暂停顿，保证能看出格位过程。
5. Phase 12.5 后，目标站位移动和招式效果位移会分段表现。
```

默认参数：

```gdscript
PRESENTATION_STEP_MOVE_DURATION = 0.12
PRESENTATION_STEP_MOVE_PAUSE = 0.045
PRESENTATION_STEP_MOVE_BOB_Y = -7.0
PRESENTATION_STEP_MOVE_MAX_STEPS = 8
```

---

## 5. Phase 11：事件驱动转身规则

```text
转身不是默认行为。
转身必须由事件触发。
玩家不会因为和敌人的相对关系自动转身。
```

会触发转身的情况：

| 场景 | 是否转身 | 时机 |
|---|---|---|
| 玩家背面受击，未死亡，未崩势 | 转身 | 受击反馈后 |
| 玩家背面受击，并被打到崩势 | 不转身 | 保持被打崩状态 |
| 玩家背面受击，并死亡 | 不转身 | 直接死亡淡出 |
| 玩家行动目标方向与当前朝向相反 | 转身 | 目标格位移动完成后、出招前 |
| 招式自带转身语义 | 转身 | 招式过程中，出招前 |
| 敌人在玩家身后，但无触发事件 | 不转身 | 保持当前朝向 |
| 玩家移动后相对敌人位置改变，但行动目标未要求转身 | 不转身 | 保持当前朝向 |
| 规则判定背向未中 | 不自动转正 | 显示“背向 / 未中” |

---

## 6. Phase 12：目标格位 / 目标朝向输入规则

总原则：

```text
目标格位决定站到哪里。
目标朝向决定站定后面向哪里。
点击新格位只改站位。
再次点击当前目标格位才改朝向。
所有招式范围预览都按目标格位与目标朝向计算。
```

点击规则：

| 操作 | 目标格位 | 目标朝向 | 招式范围预览 |
|---|---:|---|---|
| 回合开始不操作 | 当前格 | 当前实际朝向 | 当前格 + 当前朝向 |
| 点击原地格 | 当前格 | 当前朝向反转 | 当前格 + 反转朝向 |
| 点击其他合法格 | 新格 | 当前实际朝向 | 新格 + 当前实际朝向 |
| 再点该目标格 | 新格 | 目标朝向反转 | 新格 + 反转朝向 |
| 点击非法格 | 不变 | 不变 | 不变 |

合法性校验：

```text
1. slot 在 0 到 GRID_SLOT_COUNT - 1 内。
2. 不能是存活敌人所在格。
3. 距离当前玩家格位不超过 player.qinggong。
```

---

## 7. Phase 12.5：预览 / 结算 / 演出一致性修复

目标：

```text
玩家看到的目标格位 = 真实结算使用的格位 = 演出先站到的格位。
玩家看到的目标朝向 = 真实结算使用的朝向 = 演出出招前的朝向。
```

真实结算：

```text
1. resolve_intent() 开始时调用 _commit_intent_stance(intent, actor)。
2. _commit_intent_stance 会把 intent.target_position / target_facing 写入 actor。
3. _apply_resolved_positions() 不再默认 face_target(actor, target)。
4. apply_card_movement() 不再自动 face_target。
5. face_target() 保留为 legacy helper，但不再被主结算流自动调用。
```

演出顺序：

```text
1. 从旧格位逐格移动到 target slot。
2. 若目标朝向与当前不同，先转身。
3. 再播放攻击 / 防御 / 聚势。
4. 播放受击 / 未中 / 飘字。
5. 根据 effect_move 表现击退 / 拉近 / 进身 / 后撤。
6. 最后兜底落到真实 committed position。
```

---

## 8. Phase 12.6：补充修复

预览 effect step 输出：

```text
will_break
will_die
was_back_hit
back_hit_turn_to
```

表现层消费这些字段：

```text
1. 破势 FX 直接读 will_break，不再用结算后的 momentum 反推。
2. 背击转身直接读 was_back_hit。
3. 背击后若 will_break 或 will_die，则不转身。
4. 背击后若可转身，使用 back_hit_turn_to。
5. 角色死亡淡出后，后续 _refresh_ui() 会继续隐藏 hp <= 0 的角色，避免复现。
```

---

## 9. Phase 12.7：合层整理

```text
1. 将临时 wrapper `battle_controller_visual_presentation_guarded.gd` 的死亡可见性保护合回 `battle_controller_visual_presentation_stepwise.gd`。
2. 删除 `battle_controller_visual_presentation_guarded.gd`。
3. `battle_controller_visual_settlement_mode.gd` 重新直接继承 `battle_controller_visual_presentation_stepwise.gd`。
4. 修正反应式预览遗留逻辑：玩家未显式选择目标朝向时，预览不再因为敌我相对位置自动改朝向，而是保持 player.facing。
```

---

## 10. Phase 12.8：旧预览入口清理

```text
1. 原 `_effect_preview_text()` 改名为 `_legacy_effect_preview_text()`。
2. 原 `_effect_preview_context()` 改名为 `_legacy_effect_preview_context()`。
3. legacy 方法保留为调试 fallback，不再覆盖主链路的 `_effect_preview_text()`。
4. 正式效果预览继续由 `battle_controller_visual_resolver_preview.gd` 的 `_effect_preview_text()` 提供。
5. 正式效果预览继续基于 `_ordered_preview_simulation()`，保持与 target_position / target_facing / will_break / will_die / was_back_hit 同口径。
```

---

## 11. Phase 12.9：SVG FX 合层

```text
1. `battle_controller_visual_presentation_stepwise.gd` 改为直接继承 `battle_controller_visual_presentation.gd`。
2. 将 `presentation_assets.gd` 中的 SVG FX 资源路径、尺寸、透明度、层级、偏移、淡出时间等常量合入 `presentation_stepwise.gd`。
3. 将 SVG FX 方法合入 `presentation_stepwise.gd`，包括刀光、枪线、命中爆点、火器闪光、烟雾、破势墨裂、防御墨盾、聚势气纹、未中烟痕。
4. 删除 `battle_controller_visual_presentation_assets.gd`。
5. 保留原 fallback：若 SVG 加载失败，仍回退到 `presentation.gd` 的基础 ColorRect/形状反馈。
```

---

## 12. Phase 13.0：目标选择与朝向规则 helper 抽出

新增文件：

```text
scripts/battle_target_selection.gd
scripts/battle_facing_rules.gd
```

`battle_target_selection.gd` 职责：

```text
1. 判断合法目标格位。
2. 根据点击格位推导下一目标格位和目标朝向。
3. 处理“点击当前目标格 = 反转朝向”。
4. 提供 slot label 等纯 helper。
```

`battle_facing_rules.gd` 职责：

```text
1. 判断合法朝向。
2. 计算 opposite_facing / facing_sign / facing_toward_slot。
3. 判断是否背对攻击者。
4. 判断卡牌是否属于转身类招式。
5. 判断背击后是否应该转身。
```

当前状态：

```text
helper 已新增。
为避免 `presentation_stepwise.gd` 大文件在 GitHub API 中被截断覆盖，主演出层的局部接入暂未强行提交。
下一步建议在本地使用 patch 工具，将 stepwise 中的同名函数替换为 helper 转发。
```

建议接入目标：

```text
presentation_stepwise.gd:
- _is_legal_player_target_slot() → BattleTargetSelection.is_legal_target_slot()
- _current_player_target_slot() → BattleTargetSelection.current_target_slot()
- _current_player_target_facing() → BattleTargetSelection.current_target_facing()
- _on_stage_grid_slot_pressed() → BattleTargetSelection.next_selection_for_click()
- _card_has_turn_during_action() → BattleFacingRules.card_has_turn_during_action()
- _facing_exposes_back_to_slot() → BattleFacingRules.exposes_back_to_slot()
- _facing_toward_slot() → BattleFacingRules.facing_toward_slot()
- _opposite_facing() → BattleFacingRules.opposite_facing()
- _facing_sign() → BattleFacingRules.facing_sign()
- _is_valid_facing() → BattleFacingRules.is_valid_facing()
```

---

## 13. FX 资产

当前 FX 资源：

```text
assets/pixel_battle/fx/fx_firearm_flash_ink.svg
assets/pixel_battle/fx/fx_break_ink_crack.svg
assets/pixel_battle/fx/fx_miss_wisp.svg
assets/pixel_battle/fx/fx_slash_ink_arc.svg
assets/pixel_battle/fx/fx_thrust_ink_line.svg
assets/pixel_battle/fx/fx_hit_ink_burst.svg
assets/pixel_battle/fx/fx_guard_ink_shield.svg
assets/pixel_battle/fx/fx_focus_ink_ripple.svg
assets/pixel_battle/fx/fx_firearm_smoke_wisp.svg
```

FX 调参入口现在是：

```text
scripts/battle_controller_visual_presentation_stepwise.gd
```

---

## 14. 统一验收重点

```text
1. 回合开始不操作：目标格位为当前格，目标朝向为当前实际朝向。
2. 点击原地格：目标格位不变，目标朝向反转一次。
3. 点击其他合法格：目标格位变为新格，目标朝向保持当前实际朝向。
4. 点击非法格：目标格位和目标朝向不变，并给出不可移动反馈。
5. 预览显示的目标格位，就是确认后角色先逐格移动到的位置。
6. 预览显示的目标朝向，就是确认后角色出招前的朝向。
7. 真实命中 / 距外 / 背向判定与预览一致。
8. 移动或效果位移后，若没有事件触发，不会自动面向敌人。
9. 破势时稳定出现墨裂和“破势”。
10. 背击转身遵守 was_back_hit / will_break / will_die 快照。
11. 角色死亡淡出后，不应被后续 UI 刷新重新显示。
12. 反应式预览中，玩家未选择朝向时，不会因为敌方位置自动改朝向。
13. 效果预览面板显示的内容来自 resolver_preview 的顺序模拟，而不是 cached_ui 的 legacy 近似预览。
14. SVG FX 仍正常显示；若 SVG 缺失，应回退到基础表现而不阻断战斗。
```

---

## 15. 已知后续调参项

```text
1. runtime 人物动画与 presentation FX 的重复感，需要实机观察后再降噪。
2. 双方同时位移目前仍偏串行表现，后续可做并行逐格移动优化。
3. 目标格位 / 目标朝向 UI 提示仍可进一步强化，例如目标格箭头。
4. Phase 13.0 helper 接入主演出层后，再评估是否拆 Movement Presenter / FX Presenter。
```
