# 《大明之沧海嘀鸣》战斗演出层说明

> 版本：v1.3  
> 分支：`main`  
> 状态：Phase 1 已验收通过；Phase 2 / 3 / 5 / 6 / 7 / 8 / 9 / 10 / 11 / 12 / 12.5 / 12.6 已接入，待统一本地验收  
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
```

特别注意：

```text
不会仅因敌我相对位置变化自动转身。
移动目标格位与目标朝向是两个独立选择状态。
预览、真实结算、演出必须使用同一套 target_position / target_facing。
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
→ battle_controller_visual_presentation_guarded.gd
→ battle_controller_visual_presentation_stepwise.gd
→ battle_controller_visual_presentation_assets.gd
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
| `presentation_guarded` | 防止死亡淡出后被 UI 刷新重新显示 |
| `presentation_stepwise` | 逐格移动；事件驱动转身；目标格位 / 目标朝向输入规则；目标站位与效果位移分段演出 |
| `presentation_assets` | SVG FX 资产化与调参常量 |
| `presentation` | 攻击、受击、命中反馈、真实结果飘字、死亡、基础落位 |
| `battle_state_machine` | 真实结算；提交 intent target stance；不再默认自动 face_target |
| `resolver_preview` | 按 target stance 推算范围、顺序结算和最终格位，并输出破势/死亡/背击快照 |

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

---

## 4. Phase 10：逐格移动规则

用户目标：

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

### 5.1 总原则

```text
转身不是默认行为。
转身必须由事件触发。
玩家不会因为和敌人的相对关系自动转身。
```

明确禁止：

```text
敌人在左边 → 自动面向左
敌人在右边 → 自动面向右
移动后相对位置变化 → 自动面向敌人
```

### 5.2 会触发转身的情况

| 场景 | 是否转身 | 时机 |
|---|---|---|
| 玩家背面受击，未死亡，未崩势 | 转身 | 受击反馈后 |
| 玩家背面受击，并被打到崩势 | 不转身 | 保持被打崩状态 |
| 玩家背面受击，并死亡 | 不转身 | 直接死亡淡出 |
| 玩家行动目标方向与当前朝向相反 | 转身 | Phase 12.5 后：目标格位移动完成后、出招前 |
| 招式自带转身语义 | 转身 | 招式过程中，出招前 |
| 敌人在玩家身后，但无触发事件 | 不转身 | 保持当前朝向 |
| 玩家移动后相对敌人位置改变，但行动目标未要求转身 | 不转身 | 保持当前朝向 |
| 规则判定背向未中 | 不自动转正 | 显示“背向 / 未中” |

---

## 6. Phase 12：目标格位 / 目标朝向输入规则

### 6.1 总原则

```text
目标格位决定站到哪里。
目标朝向决定站定后面向哪里。
点击新格位只改站位。
再次点击当前目标格位才改朝向。
所有招式范围预览都按目标格位与目标朝向计算。
```

### 6.2 回合开始默认值

```text
目标格位 = 当前实际格位
目标朝向 = 当前实际朝向
```

玩家不做任何操作时：

```text
原地，不转向。
```

### 6.3 点击规则

| 操作 | 目标格位 | 目标朝向 | 招式范围预览 |
|---|---:|---|---|
| 回合开始不操作 | 当前格 | 当前实际朝向 | 当前格 + 当前朝向 |
| 点击原地格 | 当前格 | 当前朝向反转 | 当前格 + 反转朝向 |
| 点击其他合法格 | 新格 | 当前实际朝向 | 新格 + 当前实际朝向 |
| 再点该目标格 | 新格 | 目标朝向反转 | 新格 + 反转朝向 |
| 点击非法格 | 不变 | 不变 | 不变 |

### 6.4 实现口径

实现文件：

```text
scripts/battle_controller_visual_presentation_stepwise.gd
```

核心入口：

```gdscript
_on_stage_grid_slot_pressed(slot)
```

当前行为：

```text
1. 点击非目标格位：必须通过合法性校验。
2. 合法性校验包括：格位范围内、不能落到存活敌人所在格、不能超过 player.qinggong 步数。
3. 点击非目标合法格：draft_player_position = 点击格位；draft_player_facing = player.facing。
4. 点击已选目标格位：draft_player_position 不变；draft_player_facing 在 left / right 间反转。
5. 若 draft_player_intent 已存在，则同步 set_stance(draft_player_position, draft_player_facing)。
6. 确认出招前再次同步 draft intent，避免“先点格位后选招式”造成预览和结算不一致。
```

---

## 7. Phase 12.5：预览 / 结算 / 演出一致性修复

### 7.1 修复目标

```text
玩家看到的目标格位 = 真实结算使用的格位 = 演出先站到的格位。
玩家看到的目标朝向 = 真实结算使用的朝向 = 演出出招前的朝向。
```

### 7.2 真实结算修复

文件：

```text
scripts/battle_state_machine.gd
```

新增 / 调整：

```text
1. resolve_intent() 开始时调用 _commit_intent_stance(intent, actor)。
2. _commit_intent_stance 会把 intent.target_position / target_facing 写入 actor。
3. _apply_resolved_positions() 不再默认 face_target(actor, target)。
4. apply_card_movement() 不再自动 face_target。
5. face_target() 保留为 legacy helper，但不再被主结算流自动调用。
```

### 7.3 预览修复

文件：

```text
scripts/battle_controller_visual_resolver_preview.gd
```

调整：

```text
1. _ordered_preview_simulation() 不再用 target_position - current_position 的 delta 叠加。
2. 每个行动者在自己的行动阶段直接提交绝对目标格位。
3. 每个行动者在自己的行动阶段直接使用目标朝向。
4. 招式位移 effect_move 只改 position，不自动改 facing。
5. move step 文本显示目标格位与目标朝向。
```

### 7.4 演出顺序修复

文件：

```text
scripts/battle_controller_visual_presentation_stepwise.gd
```

现流程：

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

### 8.1 输入合法性

```text
点击新目标格位时，必须满足：
1. slot 在 0 到 GRID_SLOT_COUNT - 1 内。
2. 不能是存活敌人所在格。
3. 距离当前玩家格位不超过 player.qinggong。
```

点击当前目标格位用于反转朝向，不走新格位合法性分支。

### 8.2 破势 / 死亡 / 背击快照

文件：

```text
scripts/battle_controller_visual_resolver_preview.gd
scripts/battle_controller_visual_presentation_stepwise.gd
```

预览 effect step 现在输出：

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
```

### 8.3 死亡淡出不复现

新增文件：

```text
scripts/battle_controller_visual_presentation_guarded.gd
```

该层只做：

```text
1. 继承 presentation_stepwise。
2. 在 _refresh_character_visuals() / _set_battle_chrome_visible() 后检查死亡角色。
3. 若角色 hp <= 0，则强制隐藏对应 sprite / fallback actor。
```

`battle_controller_visual_settlement_mode.gd` 现在继承：

```gdscript
extends "res://scripts/battle_controller_visual_presentation_guarded.gd"
```

---

## 9. FX 资产

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

FX 调参入口：

```text
scripts/battle_controller_visual_presentation_assets.gd
```

---

## 10. 禁止事项

1. 不要让动画决定伤害。
2. 不要在动画层修改 HP / 势 / 卡牌消耗。
3. 不要改 `enemy_manifest.json`。
4. 不要改 `battle_scene_manifest.json`。
5. 不要改叙事 TSV / JSON。
6. 不要新增第二套战斗背景层。
7. 不要恢复旧 Debug 按钮。
8. 不要把背景路径写死到 GDScript。
9. 不要因为敌我相对位置自动转身。
10. 不要让点击新格位自动改变目标朝向。
11. 不要让预览、真实结算、演出分别使用三套站位/朝向逻辑。

---

## 11. 统一验收重点

### 目标格位 / 目标朝向输入

```text
1. 回合开始不操作：目标格位为当前格，目标朝向为当前实际朝向。
2. 回合开始不操作直接确认：玩家原地，保持当前朝向。
3. 点击原地格：目标格位不变，目标朝向反转一次。
4. 点击其他合法格：目标格位变为新格，目标朝向保持当前实际朝向。
5. 点击非法格：目标格位和目标朝向不变，并给出不可移动反馈。
6. 再点击该目标格：目标格位不变，目标朝向反转一次。
7. 先点格位 / 朝向，再选招式，确认时仍按最终目标格位和目标朝向结算。
8. 招式攻击范围预览始终按目标格位 + 目标朝向推算。
```

### Phase 12.5 / 12.6 一致性验收

```text
1. 预览显示的目标格位，就是确认后角色先逐格移动到的位置。
2. 预览显示的目标朝向，就是确认后角色出招前的朝向。
3. 真实命中 / 距外 / 背向判定与预览一致。
4. 不发生“旧格位先出招，最后才站到目标格”的表现错位。
5. 招式造成的击退 / 拉近 / 进身 / 后撤在出招后再逐格表现。
6. 移动或效果位移后，若没有事件触发，不会自动面向敌人。
7. 破势时稳定出现墨裂和“破势”，不因结算后势为 0 而漏播。
8. 背击转身遵守 was_back_hit / will_break / will_die 快照。
9. 角色死亡淡出后，不应被后续 UI 刷新重新显示。
```

### 转身逻辑

```text
1. 玩家背面受击后，若未死亡且未崩势，应转身。
2. 玩家背面受击后，若被打到崩势，不应转身。
3. 玩家背面受击后，若死亡，不应转身。
4. 玩家行动目标方向与当前朝向相反时，应在目标格位移动完成后、出招前转身。
5. 带“转身 / 回身 / 反身 / 翻身 / 回马”等语义的招式，应在出招过程中转身。
6. 敌人在玩家身后但没有触发事件时，玩家不应自动转身。
7. 玩家移动后相对敌人位置改变，但行动目标未要求转身时，不应自动转身。
8. 背向未中时，不应视觉上自动转正。
```

### 逐格移动

```text
1. 单格位移：能看清 old → new。
2. 双格位移：必须看清 old → 中间格 → new。
3. 三格位移：必须看清 old → 第1格 → 第2格 → new。
4. 攻击后击退目标 2 格时，目标应一格一格退。
5. 进身 / 后撤 / 拉近 / 击退都应逐格表现。
6. 攻击前冲仍然只作为攻击动作，不应替代真实格位移动。
```

### 基础攻击 / 受击 / FX

```text
1. 刀类攻击有水墨弧形刀光。
2. 枪类攻击有水墨直线枪影。
3. 命中有受击闪红、后退、飘字、命中爆点。
4. 擦中显示“擦中”，反馈弱于正常命中。
5. 距外显示“距外”，不触发受击闪红。
6. 背向显示“背向”，不触发受击闪红。
7. 火器有火光和烟雾。
8. 破势有墨裂和“破势”。
9. 防御有墨盾。
10. 聚势有气纹。
11. 所有效果不应明显遮挡卡牌、角色、格位和 Debug 信息。
```

当前验收状态：

```text
Phase 1: PASSED
Phase 2: SUPERSEDED_BY_PHASE_10
Phase 3: NEEDS_LOCAL_VERIFY
Phase 5: NEEDS_LOCAL_VERIFY
Phase 6: NEEDS_LOCAL_VERIFY
Phase 7: NEEDS_LOCAL_VERIFY
Phase 8: NEEDS_LOCAL_VERIFY
Phase 9: NEEDS_LOCAL_VERIFY
Phase 10: NEEDS_LOCAL_VERIFY
Phase 11: NEEDS_LOCAL_VERIFY
Phase 12: NEEDS_LOCAL_VERIFY
Phase 12.5: NEEDS_LOCAL_VERIFY
Phase 12.6: NEEDS_LOCAL_VERIFY
```

---

## 12. 已知后续调参项

以下不是规则正确性阻塞，建议统一验收后再决定是否处理：

```text
1. runtime 人物动画与 presentation FX 的重复感，需要实机观察后再降噪。
2. 双方同时位移目前仍偏串行表现，后续可做并行逐格移动优化。
3. 目标格位 / 目标朝向 UI 提示仍可进一步强化，例如目标格箭头。
```
