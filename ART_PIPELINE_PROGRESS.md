# 美术生产管线推进进度

## 当前阶段

从“资产规范文档”推进到“可执行资产验收工具链”。

本轮重点不是继续改 UI 参数，而是先建立美术资产进入项目的硬闸门：

```text
actor meta
→ sheet 尺寸 / 透明通道 / 帧数校验
→ bundle 完整度评分
→ 全局资产入口检查
```

后续任何完整角色动作包，都应该先通过这套工具，再进入 Godot 动画系统。

---

## 本轮已完成

### 1. Actor Meta 校验

新增：

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

新增：

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

新增：

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

新增：

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

## 当前约束

这套工具面向“新规范角色动画包”，也就是：

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

旧的三帧 sheet 仍然可以在游戏里兼容显示，但不作为正式动画包验收对象。

---

## 下一刀建议

下一步不应该继续扩展文档，而应该进入“单角色闭环”。

优先级：

```text
P0：创建 spearman 第一版 actor bundle 目录结构
P1：补 spearman.meta.json 示例
P2：用占位 PNG 生成最低动作集，先跑通校验
P3：新增 ActorAnimationMeta / ActorAnimationPlayer / ActorAnimationRuntime
P4：让 Godot 优先读取 actor meta；没有 meta 时再回退旧三帧 sheet
P5：把 attack_light 的 hit_frame 接到现有 FX 触发链路
```

建议从 spearman 开始，不要同时做 blademaster。先打通一个角色的完整生产与播放链路，再复制到第二个职业。

---

## 当前判断

本轮已经完成从“规范”到“验收工具”的关键跨越。

后续角色资产接入不再靠肉眼判断，而是先过工具：

```text
meta 是否可读
sheet 是否规范
动作是否完整
hit_frame 是否可用
bundle 是否达到 A / S 级
```

这一步完成后，项目已经具备继续推进完整动作动画系统的基础。下一轮应进入 ActorAnimationRuntime，而不是继续调整静态角色显示。
