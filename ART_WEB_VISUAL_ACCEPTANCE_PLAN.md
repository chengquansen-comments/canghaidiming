# 《沧海嘀鸣》Web 美术线验收推进计划 v0.1

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

## 1. 当前美术线优先级

### P0：Web 构建稳定

目标：任何美术接入都不能引入 GDScript 编译错误或 Web 构建失败。

验收：

```bash
git pull
rm -rf build/web build/web.zip
./tools/build_and_serve_web.sh
```

访问：

```text
http://127.0.0.1:8060
```

通过标准：

```text
[ ] Web 页面能打开
[ ] 浏览器控制台无 GDScript 编译错误
[ ] 中文不乱码
[ ] 角色不整张 sheet 显示
[ ] 角色不重复显示
[ ] 16:10 下无异常拉伸
```

---

### P1：敌方角色身份稳定

已知问题：敌方攻击后可能切回普通角色形象。

当前修复方向：

```text
有 enemy_{role_id}.meta.json 时，敌方 runtime 必须稳定绑定 enemy_* meta；
父级视觉刷新后，必须重新应用 actor runtime 当前帧；
旧三帧 sheet 只能作为 fallback，不能覆盖正在运行的 actor runtime。
```

验收动作：

```text
1. 进入 Web 战斗；
2. 观察敌方初始形象；
3. 选择攻击牌并确认出招；
4. 敌方播放 attack / hit / guard 后回到 idle；
5. 敌方仍保持 enemy_* 外观，不切成普通 spearman / blademaster。
```

通过标准：

```text
[ ] enemy_spearman 一直显示 enemy_spearman_sheet
[ ] enemy_blademaster 一直显示 enemy_blademaster_sheet
[ ] 攻击、受击、回 idle 后身份不变
[ ] 没有短暂闪回普通角色 sheet
```

---

### P2：意图气泡绑定角色实际 sprite

已知问题：意图气泡偶尔和角色形象发生漂移。

当前修复方向：

```text
气泡不再按格位单独计算；
气泡绑定 TextureRect 中实际绘制出来的 sprite 可见矩形；
兼容 512×512 actor meta sheet、384×384 老 sheet、横向三帧过渡 sheet；
窗口缩放、角色移动、动作切帧后都重新校准。
```

验收动作：

```text
1. 进入 Web 战斗；
2. 观察玩家 / 敌方初始气泡；
3. 选择不同移动/攻击牌；
4. 缩放浏览器窗口；
5. 多次确认出招，观察动作播放中和回 idle 后气泡位置。
```

通过标准：

```text
[ ] 气泡始终位于角色头顶附近
[ ] 气泡不会贴到格位中心而脱离角色
[ ] 角色左右移动后气泡跟随
[ ] 角色 sheet 留白不同也不造成明显偏移
[ ] 16:10 窗口缩放后位置稳定
```

---

### P3：角色动作包从三帧过渡到最低可交付包

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

---

### P4：特效与 hit_frame 对齐

当前已有运行时信号链路：

```text
ActorAnimationPlayer
→ hit_frame_reached
→ ActorAnimationRuntime
→ visual controller
→ FX feedback
```

下一步重点不是新增复杂特效，而是把已有特效稳定绑定到 hit_frame。

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

## 2. 本阶段不做的事

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

## 3. 推荐执行顺序

```text
第 1 刀：修敌方角色身份稳定
第 2 刀：修气泡绑定 sprite 实际位置
第 3 刀：补 Web 视觉验收清单
第 4 刀：spearman 最低动作包
第 5 刀：enemy_spearman 最低动作包
第 6 刀：hit_frame 特效同步验收
第 7 刀：blademaster / enemy_blademaster 复制链路
第 8 刀：UI 资产一致性补齐
```

---

## 4. 每次提交必须记录

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

## 5. 当前验收口径一句话

```text
以 1600×1000、16:10、Godot stretch/aspect=keep 为准；
角色身份不能被旧 sheet 刷新覆盖；
气泡必须绑定实际 sprite 可见区域；
新增动作资产必须 actor meta 化，并兼容旧三帧 fallback；
Web 构建稳定优先于任何视觉扩展。
```
