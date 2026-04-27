# 《大明之沧海嘀鸣》战斗演出层说明

> 版本：v0.9  
> 分支：`main`  
> 状态：Phase 1 已验收通过；Phase 2 / 3 / 5 / 6 / 7 / 8 / 9 / 10 已接入，待统一本地验收  
> 入口场景：`scenes/MainVisual.tscn`  
> 当前场景入口脚本：`scripts/battle_controller_visual_story_return.gd`

---

## 1. 当前目标

当前战斗是回合制卡牌单局，不是实时动作游戏。演出层目标是让结算结果有“武打反馈”，而不是重写动作系统。

当前完整表现链路：

```text
确认招式
→ 保持旧格位视觉起点
→ 角色前冲 / 水墨枪线 / 水墨刀光 / 火器闪光与烟雾
→ 目标受击或落空提示
→ 防御墨盾 / 聚势气纹
→ 真实结算飘字
→ 破势墨裂 / 命中停顿
→ 若结算后格位变化，则一格一格移动到最终格位
→ 死亡反馈
```

核心原则：

```text
战斗结算决定结果；演出层只消费结果、意图、卡牌信息和最终格位。
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
| `presentation_stepwise` | 结算后格位变化按格逐段移动 |
| `presentation_assets` | SVG FX 资产化与调参常量 |
| `presentation` | 攻击、受击、命中反馈、真实结果飘字、死亡、基础落位 |

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

该层只覆盖最终结算落位流程，不改：

```text
伤害结算
势结算
卡牌消耗
敌人意图
背景 manifest
剧情返回
```

当前规则：

```text
1. 确认招式前记录 player / enemy 的 old_slot。
2. super() 完成原有结算后，player / enemy 已经是 new_slot。
3. 表现层先用 presentation offset 把角色视觉拉回 old_slot。
4. 攻击 / 受击 / 飘字 / 破势等表现照常播放。
5. 如果 old_slot != new_slot，则按方向逐格移动：old → old+1 → old+2 → ... → new。
6. 每格移动都有轻微上抬和短暂停顿，保证能看出格位过程。
```

默认参数：

```gdscript
PRESENTATION_STEP_MOVE_DURATION = 0.12
PRESENTATION_STEP_MOVE_PAUSE = 0.045
PRESENTATION_STEP_MOVE_BOB_Y = -7.0
PRESENTATION_STEP_MOVE_MAX_STEPS = 8
```

调参建议：

| 问题 | 调整项 |
|---|---|
| 逐格移动太快 | 增大 `PRESENTATION_STEP_MOVE_DURATION` 或 `PRESENTATION_STEP_MOVE_PAUSE` |
| 移动太拖沓 | 减小 `PRESENTATION_STEP_MOVE_DURATION` 或 `PRESENTATION_STEP_MOVE_PAUSE` |
| 踏步感不明显 | 增大 `PRESENTATION_STEP_MOVE_BOB_Y` 的绝对值 |
| 上下跳动太夸张 | 减小 `PRESENTATION_STEP_MOVE_BOB_Y` 的绝对值 |

---

## 5. FX 资产

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

主要常量：

```gdscript
FX_Z_*
FX_ALPHA_*
FX_FADE_*
FX_SIZE_*
FX_OFFSET_*
```

---

## 6. 动画分类规则

当前按卡牌信息自动推断演出类型：

| 条件 | 演出类型 |
|---|---|
| `card.is_guard_card()` | `guard` |
| `card.is_momentum_card()` 且 `damage <= 0` | `focus` |
| `weapon_style` / `id` / `display_name` 包含火器相关词 | `firearm` |
| `weapon_style` 包含 `枪` 或 `spear` | `thrust` |
| `card.id` 包含 `spear` | `thrust` |
| 其他伤害牌 | `slash` |

当前 `CardData` 还没有显式 `anim` 字段，所以 Phase 4 暂不推进，避免牵动卡牌构建链。

---

## 7. 禁止事项

1. 不要让动画决定伤害。
2. 不要在动画层修改 HP / 势 / 卡牌消耗。
3. 不要改 `enemy_manifest.json`。
4. 不要改 `battle_scene_manifest.json`。
5. 不要改叙事 TSV / JSON。
6. 不要新增第二套战斗背景层。
7. 不要恢复旧 Debug 按钮。
8. 不要把背景路径写死到 GDScript。

---

## 8. 统一验收重点

### 基础攻击 / 受击

```text
1. 刀类攻击有水墨弧形刀光。
2. 枪类攻击有水墨直线枪影。
3. 命中有受击闪红、后退、飘字、命中爆点。
4. 敌方攻击时表现方向正确。
5. 击杀时有下沉 / 淡出。
```

### 真实结果反馈

```text
1. 正常命中显示实际伤害 / 削势。
2. 擦中显示“擦中”，反馈弱于正常命中。
3. 距外显示“距外”，不触发受击闪红。
4. 背向显示“背向”，不触发受击闪红。
5. 防御显示“守”或“守+数值”。
6. 聚势显示“势”或“势+数值”。
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

### FX 资产化

```text
1. 火器有火光和烟雾。
2. 破势有墨裂和“破势”。
3. 未中有灰色水墨掠影。
4. 防御有墨盾。
5. 聚势有气纹。
6. 所有效果不应明显遮挡卡牌、角色、格位和 Debug 信息。
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
```

---

## 9. 后续建议

下一步不建议继续新增演出逻辑，建议进入：

```text
统一验收 → 观感调参 → 再决定是否做 CardData 演出字段数据化
```

如果验收后需要继续优化，优先调：

```text
1. 逐格移动单格时长
2. 逐格移动停顿
3. FX 大小与透明度
4. 飘字位置
5. 命中停顿时长
```
