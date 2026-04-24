# 《沧海嘀鸣》动画与美术生产管线规范 v0.1

> 本文档是 `ART_ASSET_SPEC.md` 的下一层落地文档。`ART_ASSET_SPEC.md` 定义“资产应该长什么样”，本文档定义“资产如何生产、如何检查、如何接入代码、如何播放、如何验收、如何返工”。

---

## 0. 目标

当前项目已经具备 Web 版视觉 demo 的基础资产：背景、角色 sheet、头像、基础特效、UI 框体、中文字体方案。下一步目标不是继续堆单张素材，而是建立一条稳定生产管线：

```text
角色设定
→ 动作拆分
→ 美术 / AI 生成
→ 帧与锚点校验
→ meta.json 配置
→ Godot 动画接入
→ 战斗事件驱动播放
→ Web 验收
→ 返工闭环
```

本阶段完成后，项目应从“能显示角色”升级到“角色真的能完整、流畅地打斗”。

---

## 1. 生产管线总览

### 1.1 流程图

```text
需求定义
  ↓
角色动作清单
  ↓
动作帧设计 / AI Prompt
  ↓
导出 PNG sprite sheet
  ↓
编写 actor meta.json
  ↓
运行资产校验脚本
  ↓
接入 Godot ActorAnimationRuntime
  ↓
战斗事件触发动画
  ↓
Web 构建与浏览器验收
  ↓
问题归类返工
```

### 1.2 交付单位

每个角色以“角色动画包”为最小交付单位。不得只交单张立绘或无 meta 的散图。

标准角色动画包：

```text
assets/pixel_battle/actors/{role_id}/
  {role_id}_idle.png
  {role_id}_move_forward.png
  {role_id}_move_back.png
  {role_id}_attack_light.png
  {role_id}_attack_heavy.png
  {role_id}_guard.png
  {role_id}_hit.png
  {role_id}_break.png
  {role_id}_focus.png
  {role_id}_victory.png
  {role_id}_defeat.png
  {role_id}_preview.png
  {role_id}.meta.json
```

最低可交付角色包：

```text
{role_id}_idle.png
{role_id}_move_forward.png
{role_id}_attack_light.png
{role_id}_guard.png
{role_id}_hit.png
{role_id}_break.png
{role_id}.meta.json
```

低于最低可交付包，只能作为临时占位资源，不进入正式 Web demo。

---

## 2. 角色动画包规范

### 2.1 单帧尺寸

正式标准：

```text
512 × 512 px
透明背景
RGBA PNG
```

允许临时兼容：

```text
384 × 384 px
```

但新资源必须优先使用 `512 × 512`。

### 2.2 动作 sheet 尺寸

每个动作一个横向 sheet：

```text
sheet_width = frame_width × frame_count
sheet_height = frame_height
```

示例：

```text
idle：8 帧 → 4096 × 512
attack_light：8 帧 → 4096 × 512
hit：5 帧 → 2560 × 512
break：8 帧 → 4096 × 512
```

### 2.3 动作帧数标准

| 动作 | 最低帧数 | 推荐帧数 | 是否循环 | 说明 |
|---|---:|---:|---|---|
| idle | 4 | 6 - 8 | 是 | 待机呼吸、武器轻摆 |
| move_forward | 4 | 6 - 8 | 否 | 进身、抢位 |
| move_back | 4 | 6 - 8 | 否 | 后撤、避让 |
| attack_light | 6 | 8 - 10 | 否 | 普通攻击 |
| attack_heavy | 8 | 10 - 14 | 否 | 重击、终结技 |
| guard | 4 | 6 - 8 | 否 | 格挡、架势 |
| hit | 4 | 5 - 7 | 否 | 普通受击 |
| break | 6 | 8 - 10 | 否 | 破势、失衡 |
| focus | 6 | 8 - 12 | 否 / 可循环 | 聚势、先机 |
| victory | 6 | 8 - 12 | 否 | 胜利动作 |
| defeat | 6 | 8 - 12 | 否 | 失败动作 |

### 2.4 动作帧率标准

| 动作 | 推荐 fps |
|---|---:|
| idle | 8 - 10 |
| move_forward / move_back | 10 - 12 |
| attack_light | 12 - 15 |
| attack_heavy | 10 - 12 |
| guard | 8 - 10 |
| hit | 12 - 15 |
| break | 10 - 12 |
| focus | 8 - 12 |
| victory / defeat | 8 - 10 |

### 2.5 动作结构标准

每个攻击动作必须包含四段：

```text
anticipation：准备 / 前摇
strike：出手 / 武器加速
impact：命中 / 最大张力
recovery：收招 / 回到站姿
```

轻攻击推荐比例：

```text
20% anticipation
30% strike
10% impact
40% recovery
```

重攻击推荐比例：

```text
30% anticipation
25% strike
15% impact
30% recovery
```

---

## 3. 锚点与空间协议

### 3.1 必须提供的锚点

每个角色必须在 meta 中提供：

```json
{
  "frame_size": [512, 512],
  "foot_anchor": [256, 500],
  "body_center": [256, 300],
  "head_anchor": [256, 150],
  "weapon_tip_idle": [330, 280]
}
```

### 3.2 锚点含义

| 字段 | 用途 |
|---|---|
| foot_anchor | 角色站位，决定脚底踩在哪个格子 |
| body_center | 受击特效、伤害数字、锁定点 |
| head_anchor | 头顶状态、气泡、浮动提示 |
| weapon_tip_idle | 待机武器位置，用于方向和职业辨识 |
| weapon_tip_attack | 攻击帧武器尖端，用于出招特效起点 |
| impact_offset | 命中特效相对 body_center 的偏移 |

### 3.3 脚底锚点规则

```text
foot_anchor_x = frame_width / 2
foot_anchor_y = frame_height - 12
```

以 512 单帧为例：

```text
foot_anchor = [256, 500]
```

允许范围：

```text
foot_anchor_y 可在 frame_height - 8 到 frame_height - 24 之间微调。
```

禁止：

```text
同一角色不同动作 foot_anchor 不一致；
攻击帧脚底向上或向下跳动超过 6 px；
受击帧透明边界变化导致角色整体抖动；
不同帧角色中心点漂移。
```

### 3.4 格位站位规则

视觉目标：

```text
角色脚底略高于格位下缘框线；
脚底距离格位下缘 4 - 10 px；
身体可以超过格位上缘；
脚不能低于格位下缘；
人物视觉中心应对齐当前格位中心。
```

代码侧只允许通过以下参数或 meta 控制：

```text
ACTOR_RENDER_SIZE
ACTOR_FOOT_OFFSET_X
ACTOR_GROUND_Y
foot_anchor
```

禁止为了调角色位置修改：

```text
GRID_SLOT_WIDTH
GRID_SLOT_HEIGHT
GRID_SLOT_GAP
Web canvas 尺寸
场景根节点缩放
```

---

## 4. Actor meta.json Schema v0.1

### 4.1 Schema 示例

```json
{
  "schema_version": "0.1",
  "role_id": "spearman",
  "display_name": "枪手",
  "profession": "spear",
  "frame_size": [512, 512],
  "foot_anchor": [256, 500],
  "body_center": [256, 300],
  "head_anchor": [256, 150],
  "default_facing": "right",
  "scale": 1.0,
  "animations": {
    "idle": {
      "file": "spearman_idle.png",
      "frames": 8,
      "fps": 8,
      "loop": true
    },
    "move_forward": {
      "file": "spearman_move_forward.png",
      "frames": 6,
      "fps": 12,
      "loop": false,
      "root_motion": [1.0, 0.0]
    },
    "attack_light": {
      "file": "spearman_attack_light.png",
      "frames": 8,
      "fps": 14,
      "loop": false,
      "hit_frame": 5,
      "phase_frames": {
        "anticipation": [0, 1],
        "strike": [2, 4],
        "impact": [5, 5],
        "recovery": [6, 7]
      },
      "fx": "pierce_streak",
      "weapon_tip_frame": {
        "5": [430, 260]
      },
      "impact_offset": [120, -60],
      "recovery_to": "idle"
    },
    "guard": {
      "file": "spearman_guard.png",
      "frames": 6,
      "fps": 10,
      "loop": false,
      "active_frame": 3,
      "fx": "guard_flash",
      "recovery_to": "idle"
    },
    "hit": {
      "file": "spearman_hit.png",
      "frames": 5,
      "fps": 14,
      "loop": false,
      "recovery_to": "idle"
    },
    "break": {
      "file": "spearman_break.png",
      "frames": 8,
      "fps": 12,
      "loop": false,
      "recovery_to": "idle"
    }
  }
}
```

### 4.2 必填字段

```text
schema_version
role_id
display_name
frame_size
foot_anchor
body_center
default_facing
animations
```

### 4.3 每个 animation 必填字段

```text
file
frames
fps
loop
```

### 4.4 攻击动画必填字段

```text
hit_frame
phase_frames
fx
impact_offset
recovery_to
```

### 4.5 格挡动画建议字段

```text
active_frame
fx
recovery_to
```

### 4.6 受击 / 破势动画建议字段

```text
recovery_to
shake_strength
flash_color
```

---

## 5. 战斗事件到动画映射

### 5.1 基础事件映射

| 战斗事件 | 攻击方动画 | 防守方动画 | 特效 |
|---|---|---|---|
| 选择普通攻击 | attack_light | idle | 无 |
| 选择重击 | attack_heavy | idle | 无 |
| 攻击命中 | attack_light / heavy | hit | hit_spark + 职业特效 |
| 攻击被格挡 | attack_light / heavy | guard | guard_flash |
| 造成破势 | attack_heavy | break | break_burst |
| 聚势 | focus | idle | focus_aura |
| 回合开始 | idle | idle | 无 |
| 胜利 | victory | defeat | 可选 |
| 失败 | defeat | victory | 可选 |

### 5.2 出招播放顺序

标准攻击流程：

```text
1. 攻击方从 idle 切到 move_forward 或直接 attack。
2. 攻击方播放 anticipation。
3. 攻击方进入 strike。
4. 到达 hit_frame 时触发：
   - 伤害 / 格挡 / 破势结算
   - 命中特效
   - 受击方 hit / guard / break 动画
   - 震屏 / 闪白 / 伤害数字
5. 攻击方播放 recovery。
6. 双方回到 idle 或进入下一状态。
```

### 5.3 结算时机

```text
战斗数值结算必须绑定 hit_frame；
不能在动画开始时提前结算；
不能在动画结束后才显示命中特效；
格挡、破势、受击反馈必须和 hit_frame 同步。
```

---

## 6. Godot 接入方案

### 6.1 当前短期接入

短期继续兼容：

```text
TextureRect + AtlasTexture
```

由 `BattleActorRenderHelper` 负责：

```text
加载 sheet
裁帧
控制显示尺寸
控制脚底锚点
控制角色落位
```

### 6.2 下一阶段推荐接入

新增运行时模块：

```text
scripts/visual/actor_animation_runtime.gd
scripts/visual/actor_animation_meta.gd
scripts/visual/actor_animation_player.gd
```

职责：

```text
ActorAnimationMeta：读取并校验 meta.json
ActorAnimationPlayer：根据 animation 名称播放帧
ActorAnimationRuntime：绑定战斗事件、命中帧、特效触发
```

### 6.3 推荐类职责

#### ActorAnimationMeta

```text
读取 meta.json；
校验字段；
返回动作配置；
返回 foot_anchor / body_center / hit_frame。
```

#### ActorAnimationPlayer

```text
接收 TextureRect / Sprite2D；
按 fps 更新当前帧；
支持 loop / once；
暴露 frame_changed / animation_finished 信号。
```

#### ActorAnimationRuntime

```text
监听战斗事件；
切换动画；
在 hit_frame 触发特效与结算回调；
动作结束后回 idle。
```

### 6.4 短期改造顺序

```text
1. 先让三帧 sheet 继续可用。
2. 新增 meta.json 读取能力，但不强制所有角色马上迁移。
3. spearman 先接完整动画包。
4. blademaster 再接完整动画包。
5. 移除老三帧兼容逻辑。
```

---

## 7. AI 生成素材 Prompt 标准

### 7.1 通用 Prompt 必须包含

```text
pixel art wuxia combat character
transparent background
512x512 pixels per frame
horizontal sprite sheet
consistent character scale
consistent foot anchor
same costume in every frame
same weapon in every frame
no camera movement
no perspective change
no extra characters
no duplicated character copies
clean silhouette
readable weapon motion
```

### 7.2 动作 Prompt 结构

```text
角色设定：职业、年龄、服装、武器、气质
动作目标：idle / move / attack / guard / hit / break
帧数要求：例如 8 frames
画布要求：512x512 each frame, horizontal sprite sheet
锚点要求：feet stay at the same baseline, foot anchor fixed
风格要求：Chinese wuxia pixel art, dark fantasy martial arts, readable silhouette
负向要求：no duplicated bodies, no cropped feet, no inconsistent costume, no changing weapon, no background
```

### 7.3 枪手攻击 Prompt 模板

```text
A Chinese wuxia spearman pixel art character performing a straight spear thrust attack.
8 frames horizontal sprite sheet, 512x512 pixels per frame, transparent background.
Frame sequence: anticipation, forward thrust, full extension impact, recovery.
The spear tip moves clearly forward in a straight line.
Feet stay on the same baseline, consistent foot anchor, no foot sliding.
Same costume, same weapon, same body proportions in every frame.
Clean silhouette, readable motion, cold blue-white martial energy accent.
No background, no duplicated characters, no cropped feet, no perspective shift.
```

### 7.4 刀客攻击 Prompt 模板

```text
A Chinese wuxia blademaster pixel art character performing a heavy curved saber slash.
10 frames horizontal sprite sheet, 512x512 pixels per frame, transparent background.
Frame sequence: anticipation, body twist, slash acceleration, impact arc, recovery.
The saber arc is clear and readable, warm orange-red slash energy accent.
Feet stay on the same baseline, consistent foot anchor, no foot sliding.
Same costume, same weapon, same body proportions in every frame.
Clean silhouette, readable motion.
No background, no duplicated characters, no cropped feet, no perspective shift.
```

### 7.5 受击 Prompt 模板

```text
A Chinese wuxia pixel art combat character receiving a hit and staggering backward.
5 frames horizontal sprite sheet, 512x512 pixels per frame, transparent background.
The character recoils clearly but feet remain close to the same baseline.
No falling outside the frame, no cropped feet, no duplicated bodies.
Same costume, same weapon, same body proportions in every frame.
Readable silhouette, short impact reaction.
```

---

## 8. 自动验收脚本规划

### 8.1 工具列表

计划新增：

```text
tools/validate_actor_meta.py
tools/validate_actor_sheet.py
tools/validate_actor_bundle.py
tools/report_art_assets.py
```

### 8.2 validate_actor_meta.py

检查：

```text
meta.json 是否存在；
必填字段是否完整；
frame_size 是否合法；
foot_anchor 是否在画布内；
每个 animation 是否有 file / frames / fps / loop；
attack 动画是否有 hit_frame / phase_frames / fx / impact_offset；
hit_frame 是否小于 frames；
引用文件是否存在。
```

### 8.3 validate_actor_sheet.py

检查：

```text
图片是否存在；
PNG 是否为 RGBA；
宽度是否等于 frame_width × frames；
高度是否等于 frame_height；
是否透明背景；
是否疑似空图；
是否疑似多角色重复；
是否存在裁脚风险。
```

### 8.4 validate_actor_bundle.py

检查完整角色包：

```text
是否覆盖最低动作集；
所有 sheet 和 meta 是否一致；
所有攻击动作是否有 hit_frame；
所有动作是否满足最低帧数；
所有文件命名是否符合规范。
```

### 8.5 report_art_assets.py

输出资产报告：

```text
当前角色数量；
每个角色动作覆盖率；
缺失动作；
存在风险的 sheet；
Web 包体占用；
字体体积；
背景 / UI / FX 清单。
```

---

## 9. 质量分级标准

### 9.1 S 级

```text
完整动作集；
动作流畅；
脚底稳定；
命中帧明确；
特效与 hit_frame 同步；
Web 下无乱码、无裁切、无重复；
可直接进入正式 demo。
```

### 9.2 A 级

```text
覆盖最低动作集；
基本流畅；
脚底轻微误差但可接受；
hit_frame 明确；
可进入内部 demo。
```

### 9.3 B 级

```text
动作不完整；
仅适合占位；
允许存在轻微跳动；
不可用于对外演示。
```

### 9.4 C 级

```text
缺帧严重；
脚底漂移明显；
角色重复或裁切；
不能接入。
```

---

## 10. 返工标准

出现以下任一问题必须返工：

```text
中文乱码；
角色 sheet 整张显示；
角色重复出现；
脚底被裁；
脚底低于格位下缘；
攻击帧角色比例变化；
同一动作内服装或武器变化；
命中帧和特效不同步；
Web Console 出现资源加载错误；
meta 与实际图片尺寸不一致。
```

---

## 11. 与当前代码的对应关系

### 11.1 当前已存在模块

```text
BattleActorRenderHelper：角色显示、裁帧、脚底落位
BattleStageHelper：格位、范围、舞台几何
BattleHudHelper：HUD 文案与缓存
BattleSkinHelper：纹理和样式缓存
BattleFontHelper：Web 中文字体强制注入
```

### 11.2 下一步应新增模块

```text
ActorAnimationMeta
ActorAnimationPlayer
ActorAnimationRuntime
```

### 11.3 过渡原则

```text
短期保留三帧 sheet；
新增完整动画包后优先读取 meta；
meta 存在则走完整动画系统；
meta 不存在则回退到旧三帧逻辑；
所有新角色必须提供 meta。
```

---

## 12. 里程碑计划

### Milestone A：规范落地

```text
[ ] 新增 actor meta schema 文档
[ ] 新增 validate_actor_meta.py
[ ] 新增 validate_actor_sheet.py
[ ] spearman 创建第一版完整 meta
```

### Milestone B：单角色完整动画

```text
[ ] spearman 完整 idle / move / attack / guard / hit / break
[ ] Godot 读取 spearman meta
[ ] 动画能按 fps 播放
[ ] hit_frame 能触发特效
```

### Milestone C：双角色对战动画

```text
[ ] blademaster 完整动画包
[ ] 双方攻击 / 格挡 / 受击能正确切换
[ ] 破势动画接入
[ ] 职业特效差异接入
```

### Milestone D：Web 演示验收

```text
[ ] Web 16:9 黑边正常
[ ] 中文正常
[ ] 人物无重复、无裁脚、无漂移
[ ] 动作完整流畅
[ ] 浏览器无 Console error
```

---

## 13. 当前优先建议

下一步不建议马上做全角色，而是先选一个角色打通闭环：

```text
角色：spearman
动作：idle / attack_light / hit / guard / break
目标：完成 meta → 校验脚本 → Godot 播放 → hit_frame 特效
```

先把单角色跑通，再扩展到刀客。否则两个角色同时改，会把动画系统、资产质量和战斗逻辑问题混在一起。

---

## 14. 一句话原则

```text
所有新角色资产必须以“完整动作包 + meta.json + 自动校验 + 战斗事件驱动播放”为交付标准；
不再接受只有静态图或无锚点、无命中帧、无校验的散图直接进入 Web demo。
```
