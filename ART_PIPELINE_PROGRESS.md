# 美术生产管线推进进度

## 当前阶段

已经从“资产规范文档”推进到三条硬链路：

```text
资产验收工具链
动画运行时骨架
过渡 actor meta 包
```

当前重点不再是继续微调 UI，而是让项目具备完整角色动作包的接入能力，并且先用现有三帧 sheet 走通过渡链路：

```text
旧三帧 sheet
→ actor meta
→ visual controller 自动发现 meta
→ ActorAnimationRuntime 播放
→ hit_frame 信号
→ 后续接 FX / 结算反馈
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
hit_frame_reached：目前先打 log，下一步接 FX；
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

新增：

```text
assets/pixel_battle/actors/spearman/spearman.meta.json
assets/pixel_battle/actors/blademaster/blademaster.meta.json
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

当前 runtime 已接入，但战斗事件还没有真正驱动 attack / guard / hit / break 播放。

---

## 下一刀建议

下一步进入“战斗事件驱动动画”。

优先级：

```text
P0：确认 Web / Godot 编译无 GDScript 错误
P1：确认 runtime ready 日志出现 player / enemy
P2：确认角色 idle 来自 ActorAnimationRuntime，而不是旧刷新覆盖
P3：把确认出招事件接到 player_actor_runtime.play_event("attack_light")
P4：把 enemy intent 接到 enemy_actor_runtime.play_event("attack_light")
P5：hit_frame_reached 接现有 FX pool：pierce_streak / slash_arc
P6：根据 hit / guard / break 结果触发防守方动画
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
```

项目已经从“静态角色显示”推进到“新动画系统可被识别和加载”的阶段。下一轮才真正进入动作演出：

```text
确认出招
→ 播放 attack_light
→ hit_frame
→ FX
→ 受击 / 格挡 / 破势动画
```
