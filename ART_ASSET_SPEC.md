# 《沧海嘀鸣》Web 视觉资产规范 v0.2

> 本规范用于统一《沧海嘀鸣》Web 版的美术资产、角色动画、UI、特效、字体、命名与验收标准。后续新增或替换资产，必须先满足本规范，再接入代码。

---

## 0. 版本目标

### v0.2 相比 v0.1 的核心升级

1. 角色不再只要求“横向三帧可显示”，而是升级为“完整、流畅、可组合的动作动画”。
2. 角色动作必须覆盖待机、移动、出招、命中、受击、格挡、破势、胜负等基础状态。
3. 角色脚底锚点、身体中心、武器攻击点需要规范化，避免动作播放时脚底漂移、人物跳动、命中点错位。
4. UI、字体、特效、背景、Web 构建继续保持同等严格标准。
5. 所有资产必须支持 16:9 Web 运行，不因窗口变化发生拉伸、裁切、乱码或比例失真。

---

## 1. 画面基础规范

### 1.1 逻辑分辨率

统一逻辑分辨率：

```text
1600 × 900
16:9
```

要求：

```text
画面内容固定 16:9；
浏览器窗口多余区域填充黑边；
不得因窗口比例变化拉伸人物或 UI；
所有美术资产以 1600×900 作为布局基准。
```

### 1.2 页面黑边规则

Web 外层页面负责 letterbox：

```text
屏幕比 16:9 更宽：左右黑边；
屏幕比 16:9 更高：上下黑边；
游戏 canvas 始终居中；
黑边必须为纯黑或近黑色，不显示额外背景纹理。
```

### 1.3 安全区

```text
顶部 HUD 区：0 - 160 px
战斗舞台区：160 - 620 px
格位区：500 - 570 px
底部操作区：620 - 900 px
```

### 1.4 视觉层级

从下到上：

```text
背景层
↓
舞台地面层
↓
格位框线层
↓
角色层
↓
攻击范围 / 选中高亮层
↓
攻击特效层
↓
顶部 HUD 层
↓
底部卡牌 / 操作区
↓
弹窗 / 演出提示层
↓
全屏闪白 / 震屏 / 收束演出层
```

---

## 2. 角色资产总规范

### 2.1 角色资产目标

角色资产必须满足：

```text
完整：覆盖战斗中主要状态；
流畅：动作之间过渡不突兀；
稳定：脚底锚点不漂移；
可读：出招方向、命中时机、受击反馈清楚；
可复用：我方、敌方、不同职业可复用同一套代码逻辑。
```

### 2.2 角色文件结构

推荐目录：

```text
assets/pixel_battle/actors/
  spearman/
	spearman_idle.png
	spearman_walk.png
	spearman_attack_light.png
	spearman_attack_heavy.png
	spearman_guard.png
	spearman_hit.png
	spearman_break.png
	spearman_victory.png
	spearman_defeat.png
	spearman.meta.json

  blademaster/
	blademaster_idle.png
	blademaster_walk.png
	blademaster_attack_light.png
	blademaster_attack_heavy.png
	blademaster_guard.png
	blademaster_hit.png
	blademaster_break.png
	blademaster_victory.png
	blademaster_defeat.png
	blademaster.meta.json
```

当前兼容旧目录：

```text
assets/pixel_battle/sheets/{role_id}_sheet.png
assets/pixel_battle/sheets/enemy_{role_id}_sheet.png
```

但长期建议迁移到 `actors/{role_id}/`。

---

## 3. 角色动作动画规范

### 3.1 动作状态列表

正式角色至少需要以下动作：

| 动作状态 | 必须性 | 建议帧数 | 用途 |
|---|---:|---:|---|
| idle | 必须 | 6 - 8 帧 | 战斗待机、呼吸、轻微武器摆动 |
| move_forward | 必须 | 6 - 8 帧 | 进身、逼近、抢位 |
| move_back | 必须 | 6 - 8 帧 | 后撤、避让、拉开距离 |
| attack_light | 必须 | 8 - 10 帧 | 普通攻击、轻招 |
| attack_heavy | 必须 | 10 - 14 帧 | 重击、终结、强招 |
| guard | 必须 | 6 - 8 帧 | 格挡、架势、守势 |
| hit | 必须 | 5 - 7 帧 | 受击、小硬直 |
| break | 必须 | 8 - 10 帧 | 破势、失衡、较大硬直 |
| cast / focus | 可选 | 8 - 12 帧 | 聚势、蓄力、先机 |
| victory | 可选 | 8 - 12 帧 | 胜利动作 |
| defeat | 可选 | 8 - 12 帧 | 倒地 / 失败 |

### 3.2 最小可交付动作包

如果短期资源不足，最低标准为：

```text
idle：6 帧
move_forward：6 帧
attack_light：8 帧
guard：6 帧
hit：5 帧
break：8 帧
```

低于该标准的角色只能作为临时占位，不允许进入正式 Web demo。

### 3.3 动画帧率

推荐：

```text
idle：8 - 10 fps
move：10 - 12 fps
attack_light：12 - 15 fps
attack_heavy：10 - 12 fps
guard：8 - 10 fps
hit：12 - 15 fps
break：10 - 12 fps
```

原则：

```text
攻击动作要快而清楚；
受击反馈要短促明确；
待机动作不能抢戏；
重击动作可以有蓄力和收招，但总时长不宜超过 0.9 秒。
```

### 3.4 攻击动作结构

每个攻击动作必须有四段：

```text
准备段 anticipation
出手段 strike
命中段 impact
收招段 recovery
```

推荐比例：

```text
轻攻击：20% 准备 / 30% 出手 / 10% 命中 / 40% 收招
重攻击：30% 准备 / 25% 出手 / 15% 命中 / 30% 收招
```

### 3.5 命中帧规范

每个攻击动画必须标记命中帧：

```json
{
  "animation": "attack_light",
  "hit_frame": 5,
  "impact_fx": "slash_arc",
  "impact_offset": [120, -60]
}
```

命中帧要求：

```text
刀类：命中帧应位于斩击弧线最清楚的一帧；
枪类：命中帧应位于枪尖最靠近敌人的一帧；
重击：允许多个强调帧，但只能有一个主命中帧；
命中帧必须和特效、伤害结算、震屏同步。
```

### 3.6 脚底稳定性规范

所有角色动画帧必须保证：

```text
同一个动作内，支撑脚不能无理由上下跳动；
待机、出招、受击、格挡的脚底锚点必须稳定；
移动动作允许脚步变化，但角色整体落点由代码控制，帧内脚底不能大幅漂移；
攻击动作中身体可以前倾，但脚底锚点不应跨格。
```

标准锚点：

```text
foot_anchor_x = 单帧宽度 / 2
foot_anchor_y = 单帧高度 - 12
```

以 `512 × 512` 单帧为例：

```text
foot_anchor = (256, 500)
```

### 3.7 身体中心与攻击点

每个角色建议在 meta 中配置：

```json
{
  "frame_size": [512, 512],
  "foot_anchor": [256, 500],
  "body_center": [256, 300],
  "weapon_tip_idle": [330, 280],
  "weapon_tip_attack": [430, 260]
}
```

用途：

```text
foot_anchor：角色站位；
body_center：受击特效与血条浮动位置；
weapon_tip_attack：攻击特效发起点；
impact_offset：命中特效落点。
```

---

## 4. 角色 sheet 规格

### 4.1 推荐规格

正式角色不再推荐单张三帧总 sheet 作为最终形态，而是推荐“每个动作一个 sheet”。

单帧：

```text
512 × 512
```

动作 sheet：

```text
宽度 = 512 × 帧数
高度 = 512
```

示例：

```text
idle 8 帧：4096 × 512
attack_light 8 帧：4096 × 512
hit 5 帧：2560 × 512
```

### 4.2 当前兼容规格

现有三帧 sheet 继续兼容：

```text
Frame 0：待机
Frame 1：攻击
Frame 2：受击 / 蓄势
```

但只能作为过渡方案。

### 4.3 禁止项

```text
禁止把多个动作无规则拼到一张大图中；
禁止每帧画布大小不同；
禁止脚底位置每帧不一致；
禁止透明边距随机变化；
禁止把 .svg 作为正式运行主资产；
禁止横向 sheet 未裁切就整张显示。
```

---

## 5. 角色显示与 UI 调参规范

### 5.1 调参集中位置

角色显示大小与站位只允许集中在：

```text
scripts/visual/battle_actor_view.gd
```

核心参数：

```gdscript
ACTOR_RENDER_SIZE
ACTOR_FOOT_OFFSET_X
ACTOR_GROUND_Y
```

### 5.2 禁止乱改位置

不允许为了调人物去改：

```text
GRID_SLOT_WIDTH
GRID_SLOT_HEIGHT
GRID_SLOT_GAP
stage grid 构建逻辑
slot_top_left 基础算法
Web canvas 尺寸
```

### 5.3 站位目标

```text
人物脚底略高于格位下缘框线；
脚底距离格位下缘建议 4 - 10 px；
人物身体可以超出格位上缘；
脚不能低于格位下缘；
人物视觉中心应对齐当前格位中心。
```

### 5.4 调参口诀

```text
人物大小不对：改 ACTOR_RENDER_SIZE
人物左右偏：改 ACTOR_FOOT_OFFSET_X
人物上下偏：改 ACTOR_GROUND_Y
```

---

## 6. 职业动作风格规范

### 6.1 枪手 Spearman

动作特征：

```text
直线、穿刺、压迫、重心稳定；
攻击前摇短，出手干净；
武器延展要明显，枪尖方向清楚；
命中特效偏蓝白冷光。
```

动作重点：

```text
attack_light：中平直刺，枪尖向前；
attack_heavy：长距离贯穿，身体压低；
guard：回枪成圆，形成防守圈；
break：枪杆下坠，身体后仰或单膝失衡。
```

### 6.2 刀客 Blademaster

动作特征：

```text
弧线、爆发、近身、身体旋转；
攻击前摇更明显，打击更重；
刀光弧线清楚；
命中特效偏橙红暖光。
```

动作重点：

```text
attack_light：赶步斩，横向或斜向弧线；
attack_heavy：断流重斩，强前摇强收招；
guard：藏锋格，低身收刀；
break：刀身下沉，身体侧偏。
```

---

## 7. 特效规范

### 7.1 特效分类

| 特效 | 文件示例 | 用途 |
|---|---|---|
| hit_spark | hit_spark.png | 通用命中火花 |
| pierce_streak | pierce_streak.png | 枪类穿刺线 |
| slash_arc | slash_arc.png | 刀类斩击弧 |
| guard_flash | guard_flash.png | 格挡反馈 |
| break_burst | break_momentum_burst.png | 破势爆点 |
| focus_aura | focus_aura.png | 聚势 / 先机 |

### 7.2 特效尺寸

```text
小型命中：256 × 256
横向穿刺：512 × 128
斩击弧光：512 × 256
格挡闪光：384 × 384
破势爆点：512 × 512
```

### 7.3 特效同步

```text
攻击命中帧触发命中特效；
伤害数字 / 受击动画 / 震屏同时触发；
格挡成功时不播完整命中特效，而播 guard_flash；
破势时额外播 break_burst；
重击可叠加屏幕闪白，但不能遮挡 UI 超过 0.15 秒。
```

---

## 8. 背景规范

### 8.1 尺寸

```text
1600 × 900
16:9
```

### 8.2 背景中部留白

```text
角色活动区域：x = 300 - 1300，y = 250 - 560
不得放过强亮点；
不得用高对比纹理干扰角色脚底；
格位区必须能看清线框和高亮。
```

### 8.3 背景层次

```text
远景低对比；
中景营造气氛；
近景避免遮挡格位；
地面需要有明确承重感。
```

---

## 9. UI 资产规范

### 9.1 UI 风格

```text
暗底；
金色描边；
低饱和蓝灰填充；
攻击用朱红强调；
防御用铁青强调；
势 / 身法用青绿强调；
避免现代霓虹感。
```

### 9.2 基础 UI 资产

```text
assets/pixel_battle/ui/panel_frame.png
assets/pixel_battle/ui/button_frame.png
```

### 9.3 建议补充

```text
card_frame_attack.png
card_frame_guard.png
card_frame_momentum.png
hud_avatar_frame.png
intent_bubble_frame.png
tooltip_panel.png
momentum_dot_full.png
momentum_dot_empty.png
hp_bar_fill.png
guard_icon.png
break_icon.png
```

### 9.4 卡牌规格

当前显示尺寸：

```text
176 × 204
```

正式绘制规格：

```text
352 × 408
2x 绘制，代码中缩放显示
```

每张卡牌必须包含：

```text
费用
名称
类型标签
核心效果字
限制 / combo 标记
```

---

## 10. 字体规范

### 10.1 Web 字体

Web 端必须内嵌中文字体：

```text
assets/fonts/cjk_font.ttf
```

要求：

```text
必须是真 TTF / OTF；
不能用 .ttc 改名成 .ttf；
必须通过 validate_cjk_font.py 校验；
正式发布建议使用 Noto Sans SC / 思源黑体并做子集化。
```

### 10.2 运行时字体注入

所有动态 UI 必须能被：

```text
BattleFontHelper
```

递归覆盖。不能只依赖 `project.godot` 的全局 theme。

---

## 11. 文件格式规范

### 11.1 正式运行资源

```text
角色 / 背景 / UI / 特效：PNG
字体：TTF / OTF
数据：JSON
```

### 11.2 源文件

源文件可以保留：

```text
SVG
PSD
Aseprite
Figma
Krita
```

但正式 Web 运行优先加载 PNG，不推荐以 SVG 作为主运行资源。

### 11.3 透明规范

```text
角色：透明背景 RGBA PNG
特效：透明背景 RGBA PNG
UI 框：透明背景 RGBA PNG
背景：不透明 PNG
```

---

## 12. 命名规范

### 12.1 角色

```text
assets/pixel_battle/actors/{role_id}/{role_id}_{animation}.png
assets/pixel_battle/actors/{role_id}/{role_id}.meta.json
```

示例：

```text
spearman_idle.png
spearman_attack_light.png
spearman_guard.png
spearman.meta.json
```

### 12.2 敌方角色

优先复用同一套动画，通过 shader / modulate / 镜像 / 调色区分敌方。

如果必须单独制作：

```text
enemy_{role_id}_{animation}.png
```

### 12.3 特效

```text
assets/pixel_battle/fx/{fx_id}.png
```

### 12.4 UI

```text
assets/pixel_battle/ui/{ui_element}_{state}.png
```

示例：

```text
button_normal.png
button_hover.png
button_pressed.png
card_frame_attack.png
```

---

## 13. 动画 meta 规范

每个角色必须提供 meta 文件：

```text
assets/pixel_battle/actors/{role_id}/{role_id}.meta.json
```

示例：

```json
{
  "role_id": "spearman",
  "frame_size": [512, 512],
  "foot_anchor": [256, 500],
  "body_center": [256, 300],
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
	  "loop": false
	},
	"attack_light": {
	  "file": "spearman_attack_light.png",
	  "frames": 8,
	  "fps": 14,
	  "loop": false,
	  "hit_frame": 5,
	  "fx": "pierce_streak",
	  "impact_offset": [120, -60]
	},
	"guard": {
	  "file": "spearman_guard.png",
	  "frames": 6,
	  "fps": 10,
	  "loop": false
	},
	"hit": {
	  "file": "spearman_hit.png",
	  "frames": 5,
	  "fps": 14,
	  "loop": false
	},
	"break": {
	  "file": "spearman_break.png",
	  "frames": 8,
	  "fps": 12,
	  "loop": false
	}
  }
}
```

---

## 14. 动画状态机规范

### 14.1 基础状态流

```text
idle
→ move_forward / move_back
→ attack_light / attack_heavy / guard / focus
→ hit / break / idle
```

### 14.2 出招流程

```text
选择招式
→ 角色移动到目标格
→ 播放攻击前摇
→ 命中帧触发特效与结算
→ 目标播放 hit / guard / break
→ 攻击方收招
→ 双方回到 idle
```

### 14.3 动作不可跳帧规则

```text
攻击动作不能直接从 idle 跳到命中帧；
重击必须保留前摇；
受击必须保留至少 0.2 秒可见反馈；
破势必须优先于普通受击表现；
战斗结算不能早于命中帧。
```

---

## 15. 资产验收清单

### 15.1 角色动作

```text
[ ] 是否覆盖 idle / move / attack / guard / hit / break？
[ ] 每个动作是否有足够帧数？
[ ] 攻击动作是否有 anticipation / strike / impact / recovery？
[ ] 是否标记 hit_frame？
[ ] 脚底锚点是否稳定？
[ ] 是否没有透明边距随机变化？
[ ] 播放时是否没有人物抖动？
[ ] 移动后是否能准确站回格位？
```

### 15.2 角色站位

```text
[ ] 脚底是否略高于格位下缘？
[ ] 人物是否站在格子中？
[ ] 人物是否没有穿出下边界？
[ ] 双方角色比例是否一致？
[ ] 攻击帧是否不会导致脚底大幅漂移？
```

### 15.3 背景

```text
[ ] 是否 16:9？
[ ] 是否 1600×900 或同等比例？
[ ] 是否给角色留出中部空间？
[ ] 格位框是否清晰可见？
[ ] 背景亮度是否不会压过角色？
```

### 15.4 UI

```text
[ ] 中文是否正常显示？
[ ] 按钮是否可读？
[ ] 卡牌是否不溢出？
[ ] HUD 信息是否层级清楚？
[ ] 深色背景下是否有足够对比？
```

### 15.5 Web

```text
[ ] 是否通过字体校验？
[ ] 是否能导出 Web？
[ ] 是否 16:9 黑边正常？
[ ] 是否浏览器无 Console error？
[ ] 是否没有中文乱码？
[ ] 是否没有角色 sheet 整张显示？
[ ] 是否没有重复角色？
```

---

## 16. 当前阶段优先级

```text
P0：角色动作 sheet 规格从三帧过渡到完整动作集
P1：角色脚底锚点和站位稳定
P2：攻击动画 hit_frame 与特效同步
P3：卡牌 UI 框和状态图标补齐
P4：职业差异化特效补齐
P5：字体子集化，降低 Web 包体
P6：更多背景场景扩展
```

---

## 17. 一句话总规范

```text
画面固定 1600×900、16:9 黑边；
角色资产按“完整动作集 + 稳定脚底锚点 + 明确命中帧”制作；
UI 按“暗底金边 + 中文内嵌字体 + 动态字体注入”执行；
特效必须和动作命中帧同步；
所有位置和显示参数集中在 helper，不允许散落在多个 controller 中。
```
