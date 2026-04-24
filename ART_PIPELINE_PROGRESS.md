# 美术生产管线推进进度

## 当前阶段

已经从“资产规范文档”推进到两条硬链路：

```text
资产验收工具链
动画运行时骨架
```

当前重点不再是继续微调 UI，而是让项目具备完整角色动作包的接入能力：

```text
actor meta
→ sheet 尺寸 / 透明通道 / 帧数校验
→ bundle 完整度评分
→ meta 运行时读取
→ 按 fps 播放横向动作 sheet
→ hit_frame 信号
→ 动画结束回 idle
```

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

当前还没有完整 actor bundle 时，可临时允许空目录：

```bash
python3 tools/validate_art_assets.py --allow-empty
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

## 当前约束

新工具链面向“新规范角色动画包”：

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

旧三帧 sheet 仍然由当前 visual controller 兼容显示，但不作为正式动画包验收对象。

动画运行时骨架已经可用，但还没有接入当前 `battle_controller_visual_cached_ui.gd` 主流程。

---

## 下一刀建议

下一步进入“单角色闭环”，不要同时做双角色和全战斗接入。

优先级：

```text
P0：创建 spearman 第一版 actor bundle 目录结构
P1：补 spearman.meta.json 示例
P2：用占位 PNG 生成最低动作集，先跑通校验
P3：在 visual controller 中建立 player_actor_runtime / enemy_actor_runtime
P4：有 meta 时优先走 ActorAnimationRuntime，没有 meta 时回退旧三帧 sheet
P5：把 attack_light 的 hit_frame 接到现有 FX 触发链路
```

建议从 spearman 开始，不要同时做 blademaster。先打通一个角色的完整生产、校验、播放、hit_frame 链路，再复制到第二个职业。

---

## 当前判断

本轮完成了关键跨越：

```text
规范文档
→ 资产验收工具
→ 动画运行时骨架
```

项目现在已经具备接入完整动作动画包的工程基础。下一轮应集中在一个闭环：

```text
spearman meta + 占位动作 sheet
→ 校验通过
→ Godot runtime 播放
→ hit_frame 触发 FX
```
