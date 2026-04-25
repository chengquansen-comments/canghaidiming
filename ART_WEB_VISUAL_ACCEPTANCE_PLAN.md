# 《沧海嘀鸣》Web 美术线验收推进计划 v0.2

> 本文档承接 `ART_ASSET_SPEC.md`、`ANIMATION_AND_ART_PIPELINE_SPEC.md`、`ART_PIPELINE_PROGRESS.md`。当前阶段不再从头设计战斗规则，专门推进 Web 美术线：角色动作、sprite sheet、特效、UI 一致性、角色/气泡绑定、Web 视觉验收。

---

## 0. 当前真实基准

```text
Godot 逻辑分辨率：1600 × 1000
画面比例：16:10
Web 外壳：只铺满浏览器黑底，不再自行裁切 16:9 / 16:10
比例控制：交给 Godot stretch/aspect=keep
当前主场景：scenes/MainVisual.tscn
当前主控制器：scripts/battle_controller_visual_responsive_ui.gd
```

注意：历史文档中仍有 `1600 × 900`、`16:9` 口径。后续美术执行以本文档和当前 `project.godot` 为准，旧 16:9 口径只作为历史参考，不再作为当前 Web demo 验收标准。

---

## 1. 验收状态总览

```text
[PASSED] P0：Web 构建稳定
[PASSED] P1：敌方角色身份稳定
[PASSED] P2：意图气泡绑定角色实际 sprite
[NEXT]   P3：角色动作包从三帧过渡到最低可交付包
[TODO]   P4：特效与 hit_frame 对齐
[TODO]   P5：UI 视觉一致性
```

当前重心已经从“Web 是否稳定、角色是否漂移”切到“最低动作包生产与接入”。

---

## 2. 已通过验收

### P0：Web 构建稳定

验收命令：

```bash
git pull
rm -rf build/web build/web.zip
./tools/build_and_serve_web.sh
```

访问：

```text
http://127.0.0.1:8060
```

通过结果：

```text
[x] Web 页面能打开
[x] 浏览器控制台无 GDScript 编译错误
[x] 中文不乱码
[x] 角色不整张 sheet 显示
[x] 角色不重复显示
[x] 16:10 下无异常拉伸
```

---

### P1：敌方角色身份稳定

已通过结果：

```text
[x] enemy_spearman 一直显示 enemy_spearman_sheet
[x] enemy_blademaster 一直显示 enemy_blademaster_sheet
[x] 攻击、受击、回 idle 后身份不变
[x] 没有短暂闪回普通角色 sheet
```

当前结论：

```text
有 enemy_{role_id}.meta.json 时，敌方 runtime 已能稳定绑定 enemy_* meta；
父级视觉刷新后不会再把 active enemy runtime 覆盖成普通角色 sheet；
旧三帧 sheet fallback 保持兼容。
```

---

### P2：意图气泡绑定角色实际 sprite

已通过结果：

```text
[x] 气泡始终位于角色头顶附近
[x] 气泡不会贴到格位中心而脱离角色
[x] 角色左右移动后气泡跟随
[x] 角色 sheet 留白不同也不造成明显偏移
[x] 16:10 窗口缩放后位置稳定
```

当前结论：

```text
气泡已从“按格位单独计算”切到“绑定 TextureRect 中实际绘制出来的 sprite 可见矩形”；
512×512 actor meta sheet、384×384 老 sheet、横向三帧过渡 sheet 均保持兼容。
```

---

## 3. 当前下一刀：P3 角色动作包从三帧过渡到最低可交付包

短期不要求一次做完整 S 级动作包。先完成最低可交付包，保证 runtime、meta、FX、Web 验收链路跑通。

最低动作集：

```text
idle
move_forward
attack_light
guard
hit
break
```

推荐优先角色：

```text
1. spearman
2. enemy_spearman
3. blademaster
4. enemy_blademaster
```

每个角色包目录：

```text
assets/pixel_battle/actors/{role_id}/
  {role_id}_idle.png
  {role_id}_move_forward.png
  {role_id}_attack_light.png
  {role_id}_guard.png
  {role_id}_hit.png
  {role_id}_break.png
  {role_id}.meta.json
```

过渡兼容要求：

```text
旧 assets/pixel_battle/sheets/*_sheet.png 必须继续可用；
新动作包存在时优先走 actor meta runtime；
新动作包缺失时回退旧三帧 sheet；
不得因为某个新动作缺图导致 Web 崩溃。
```

### P3 建议执行拆分

```text
P3.1：先为 spearman 建立最低动作包目录与 meta 口径
P3.2：确认 validate_actor_bundle.py 能识别动作覆盖率
P3.3：接入 spearman_idle / attack_light / guard / hit / break / move_forward
P3.4：Web 验收 spearman 动作切换无抖动、无整张 sheet、无裁脚
P3.5：复制链路到 enemy_spearman
P3.6：再扩展 blademaster / enemy_blademaster
```

---

## 4. 后续待验收

### P4：特效与 hit_frame 对齐

当前已有运行时信号链路：

```text
ActorAnimationPlayer
→ hit_frame_reached
→ ActorAnimationRuntime
→ visual controller
→ FX feedback
```

优先特效：

```text
spearman：pierce_streak
blademaster：slash_arc
guard：guard_flash
break：break_burst / break_momentum_burst
focus：focus_aura
```

通过标准：

```text
[ ] 攻击开始时不提前播命中特效
[ ] hit_frame 到达时才播主特效
[ ] 受击/格挡/破势反馈和 hit_frame 同步
[ ] 特效不遮挡底部手牌和核心 UI
[ ] Web 下特效不造成明显卡顿
```

---

### P5：UI 视觉一致性

当前原则：不大改底部 UI 稳定结构，只做视觉一致性补齐。

优先补齐：

```text
intent_bubble_frame.png
card_frame_attack.png
card_frame_guard.png
card_frame_momentum.png
hud_avatar_frame.png
momentum_dot_full.png
momentum_dot_empty.png
guard_icon.png
break_icon.png
```

通过标准：

```text
[ ] 暗底金边风格一致
[ ] 攻击 / 防御 / 势 三类卡牌能一眼区分
[ ] 气泡、HUD、卡牌、弹窗不割裂
[ ] 字体大小在 1600×1000 下清晰
[ ] 详情面板缩小时不挤掉手牌
```

---

## 5. 本阶段不做的事

为了避免美术线失焦，以下内容暂不推进：

```text
不重构 Web shell；
不重构底部响应式 UI；
不大改战斗规则；
不新增复杂职业系统；
不扩展大量角色；
不一次性追求全量 S 级动画；
不移除旧三帧 sheet fallback。
```

---

## 6. 当前执行顺序

```text
已完成：Web 构建稳定
已完成：敌方角色身份稳定
已完成：气泡绑定 sprite 实际位置
当前：spearman 最低动作包
下一步：enemy_spearman 最低动作包
随后：hit_frame 特效同步验收
随后：blademaster / enemy_blademaster 复制链路
最后：UI 资产一致性补齐
```

---

## 7. 每次提交必须记录

每次推进后，在回复或进度文档中记录：

```text
分支：feature/symmetry-gameplay
提交 SHA：<commit_sha>
改动文件：<paths>
验证命令：./tools/build_and_serve_web.sh
验证结果：通过 / 未验证 / 失败原因
下一步：<one clear next action>
```

---

## 8. 当前验收口径一句话

```text
以 1600×1000、16:10、Godot stretch/aspect=keep 为准；
P0–P2 已通过；
下一阶段集中推进 spearman 最低动作包；
新增动作资产必须 actor meta 化，并兼容旧三帧 fallback；
Web 构建稳定优先于任何视觉扩展。
```
