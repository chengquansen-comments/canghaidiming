# 美术生产管线推进进度

## 当前阶段

已经从“资产规范文档”推进到四条硬链路：

```text
资产验收工具链
动画运行时骨架
过渡 actor meta 包
Web 美术验收闭环
```

当前重点不再是继续微调 UI，也不是继续改战斗规则，而是围绕 Web 美术线做闭环：

```text
旧三帧 sheet
→ actor meta
→ visual controller 自动发现 meta
→ ActorAnimationRuntime 播放
→ hit_frame 信号
→ FX / 受击反馈
→ sprite 绑定气泡
→ Web 视觉验收
```

---

## 当前真实画面基准

当前项目已经切到：

```text
逻辑分辨率：1600 × 1000
画面比例：16:10
Web 外壳：浏览器黑底铺满，不自行裁切
比例控制：Godot stretch/aspect=keep
主场景：scenes/MainVisual.tscn
主控制器：scripts/battle_controller_visual_responsive_ui.gd
```

历史规范文档里仍可能出现 `1600 × 900`、`16:9` 口径。后续执行以当前项目真实配置和 `ART_WEB_VISUAL_ACCEPTANCE_PLAN.md` 为准。

---

## 已完成一：资产验收工具链

### 1. Actor Meta 校验

```text
tools/validate_actor_meta.py
```

检查内容：

```text
schema_version / role_id / display_name
frame_size / foot_anchor / body_center
default_facing
animations
每个 animation 的 file / frames / fps / loop
attack 动画的 hit_frame / phase_frames / fx / impact_offset / recovery_to
引用文件是否存在
hit_frame 是否越界
foot_anchor 是否在合理范围
```

使用方式：

```bash
python3 tools/validate_actor_meta.py assets/pixel_battle/actors/spearman/spearman.meta.json
python3 tools/validate_actor_meta.py assets/pixel_battle/actors/spearman
```

---

### 2. Actor Sheet 校验

```text
tools/validate_actor_sheet.py
```

检查内容：

```text
是否 PNG
是否 RGBA
宽度是否等于 frame_width × frames
高度是否等于 frame_height
是否全透明
alpha 覆盖率是否异常
```

依赖：

```bash
python3 -m pip install pillow
```

使用方式：

```bash
python3 tools/validate_actor_sheet.py assets/pixel_battle/actors/spearman/spearman.meta.json
python3 tools/validate_actor_sheet.py assets/pixel_battle/actors/spearman
```

---

### 3. Actor Bundle 校验

```text
tools/validate_actor_bundle.py
```

作用：

```text
串联 meta 校验 + sheet 校验；
检查最低动作集；
给角色动画包打 S / A / C 级；
输出角色动作覆盖摘要。
```

最低动作集：

```text
idle
move_forward
attack_light
guard
hit
break
```

推荐动作集：

```text
move_back
attack_heavy
focus
victory
defeat
```

使用方式：

```bash
python3 tools/validate_actor_bundle.py assets/pixel_battle/actors/spearman
```

---

### 4. 全局美术资产入口

```text
tools/validate_art_assets.py
```

作用：

```text
扫描 assets/pixel_battle/actors 下所有带 *.meta.json 的角色目录；
逐个执行 actor bundle 校验；
作为后续 CI / 构建前校验入口。
```

使用方式：

```bash
python3 tools/validate_art_assets.py
```

---

## 已完成二：动画运行时骨架

### 1. ActorAnimationMeta

```text
scripts/visual/actor_animation_meta.gd
```

职责：

```text
读取 actor meta.json；
解析 role_id / frame_size / foot_anchor / body_center / head_anchor；
解析 animations；
提供 animation_frames / animation_fps / animation_hit_frame / animation_fx 等统一接口；
提供 preferred_idle / first_animation_name 等回退接口。
```

### 2. ActorAnimationPlayer

```text
scripts/visual/actor_animation_player.gd
```

职责：

```text
绑定 ActorAnimationMeta 与 TextureRect；
按 fps 播放横向 sprite sheet；
根据 frame_size 裁 AtlasTexture；
支持 loop / once；
发出 frame_changed；
在 hit_frame 发出 hit_frame_reached；
动作结束后发出 animation_finished。
```

### 3. ActorAnimationRuntime

```text
scripts/visual/actor_animation_runtime.gd
```

职责：

```text
绑定 actor_key / meta_path / TextureRect；
统一 play / play_idle / play_event；
把事件名映射到动画名；
转发 hit_frame_reached，并带出 fx_id / impact_offset；
动画结束后根据 recovery_to 回 idle；
meta 缺失或非法时发出 runtime_failed。
```

---

## 已完成三：Visual Controller 过渡接入

```text
scripts/battle_controller_visual_cached_ui.gd
```

当前逻辑：

```text
有 actor meta：优先走 ActorAnimationRuntime；
没有 actor meta：保留旧三帧 sheet 显示；
_process(delta)：更新 player / enemy runtime；
_refresh_character_visuals()：确保 runtime 存在并回 idle；
hit_frame_reached：已进入 visual controller，可继续接 FX / 防守方反馈；
runtime_failed：不阻断旧逻辑。
```

meta 自动发现路径：

```text
res://assets/pixel_battle/actors/{role_id}/{role_id}.meta.json
res://assets/pixel_battle/actors/enemy_{role_id}/enemy_{role_id}.meta.json
```

---

## 已完成四：过渡 actor meta 包

当前不等待新美术，先用现有三帧 sheet 建立可被 runtime 识别的 actor meta。

当前已有：

```text
assets/pixel_battle/actors/spearman/spearman.meta.json
assets/pixel_battle/actors/blademaster/blademaster.meta.json
assets/pixel_battle/actors/enemy_spearman/enemy_spearman.meta.json
assets/pixel_battle/actors/enemy_blademaster/enemy_blademaster.meta.json
```

过渡策略：

```text
继续引用现有 assets/pixel_battle/sheets/*.png；
frame_size 按 512×512；
frames 暂时使用 3；
idle fps 设置为极低值，避免待机快速轮播三帧；
attack_light 的 hit_frame 设置为 1；
spearman fx = pierce_streak；
blademaster fx = slash_arc。
```

这不是最终动作包，只是为了把链路先跑通：

```text
旧资产
→ meta 包装
→ runtime 自动接入
→ 后续替换成完整动作 sheet
```

---

## 已完成五：Web 美术验收计划

新增：

```text
ART_WEB_VISUAL_ACCEPTANCE_PLAN.md
```

该文档把当前美术线推进收口为六个验收主题：

```text
P0：Web 构建稳定
P1：敌方角色身份稳定
P2：意图气泡绑定角色实际 sprite
P3：角色动作包从三帧过渡到最低可交付包
P4：特效与 hit_frame 对齐
P5：UI 视觉一致性
```

该文档同时明确：

```text
当前 Web demo 以 1600×1000、16:10、Godot stretch/aspect=keep 为准；
旧 1600×900 / 16:9 文档口径不再作为当前验收标准；
所有新动作资产必须 actor meta 化，同时兼容旧三帧 fallback；
Web 构建稳定优先于任何视觉扩展。
```

---

## 最近一次代码修复

### 1. 敌方角色攻击后形象切换

改动位置：

```text
scripts/battle_controller_visual_responsive_ui.gd
```

处理方向：

```text
父级 visual refresh 仍可能把旧三帧 sheet 写回 TextureRect；
responsive 层在刷新后重新调用 actor runtime；
有 enemy_* meta 时，敌方角色保持 enemy_* sheet 身份；
旧三帧只作为 fallback，不应覆盖 active runtime。
```

### 2. 意图气泡与角色 sprite 绑定

改动位置：

```text
scripts/battle_controller_visual_responsive_ui.gd
```

处理方向：

```text
气泡不按格位独立计算；
气泡绑定 TextureRect 中实际绘制出来的 sprite 可见矩形；
兼容 512×512 actor meta sheet、384×384 老 sheet、横向过渡 sheet；
窗口缩放、角色移动、动作切帧后持续校准。
```

---

## 当前约束

旧三帧 sheet 仍然只是过渡资产。正式动画包仍然应该迁移到：

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

但在完整动作包稳定前，必须继续满足：

```text
旧三帧 sheet 可用；
meta 缺失时可回退；
单个动作缺失不导致 Web 崩溃；
Web 构建稳定优先。
```

---

## 下一刀建议

下一步进入“Web 美术验收闭环 + 单角色最低动作包”。

优先级：

```text
P0：本地执行 ./tools/build_and_serve_web.sh，确认无 GDScript 编译错误
P1：确认 runtime ready 日志出现 player / enemy
P2：确认 enemy_* 攻击、受击、回 idle 后不切回普通 sheet
P3：确认气泡绑定 sprite 实际绘制区域，缩放和移动后不漂
P4：用 spearman 做最低动作包：idle / move_forward / attack_light / guard / hit / break
P5：跑 tools/validate_art_assets.py，形成动作覆盖报告
P6：再复制到 enemy_spearman、blademaster、enemy_blademaster
P7：最后补 UI frame / icon / FX 一致性资产
```

---

## 当前判断

本轮完成了关键过渡：

```text
规范文档
→ 资产验收工具
→ 动画运行时骨架
→ visual controller 接入
→ 现有三帧资产 meta 化
→ 角色身份与气泡绑定修复
→ Web 美术验收计划
```

项目已经从“静态角色显示”推进到“Web 美术验收闭环”的阶段。下一轮不应再扩规则，而应直接打通：

```text
spearman 最低动作包
→ actor bundle 校验
→ Web 运行验收
→ enemy / blademaster 复制
→ UI / FX 一致性补齐
```
