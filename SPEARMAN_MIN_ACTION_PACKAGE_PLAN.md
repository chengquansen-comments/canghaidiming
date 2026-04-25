# Spearman 最低动作包推进计划 v0.1

> 目标：在不破坏当前 Web 稳定性的前提下，把 spearman 从“旧三帧 sheet + meta 包装”推进到“最低动作包 + actor bundle 校验 + Web 动作验收”。

---

## 0. 当前判断

当前 spearman 已经具备最低动作集字段：

```text
idle
move_forward
attack_light
guard
hit
break
```

但这些动作仍全部指向：

```text
assets/pixel_battle/sheets/spearman_sheet.png
```

所以当前状态只能算：

```text
P3.1 meta 口径已具备
P3.2 校验链路可运行
P3.3 正式动作图尚未替换
```

本阶段不要直接追求完整 S 级动画，而是先把 spearman 做到 A 级可演示。

---

## 1. 最低动作包目录

正式目标目录：

```text
assets/pixel_battle/actors/spearman/
  spearman_idle.png
  spearman_move_forward.png
  spearman_attack_light.png
  spearman_guard.png
  spearman_hit.png
  spearman_break.png
  spearman.meta.json
```

过渡兼容：

```text
如果上述动作 PNG 未全部到位，spearman.meta.json 可以继续引用 ../../sheets/spearman_sheet.png；
但 Web demo 不允许因为缺图崩溃；
正式替换时一次只替换 spearman，不同时动 enemy_spearman / blademaster。
```

---

## 2. 动作规格

### 2.1 idle

```text
文件：spearman_idle.png
单帧：512 × 512
帧数：6 - 8
fps：8
loop：true
要求：轻微呼吸、枪杆微动、脚底稳定。
```

### 2.2 move_forward

```text
文件：spearman_move_forward.png
单帧：512 × 512
帧数：6
fps：10 - 12
loop：false
recovery_to：idle
要求：进身抢位，身体前压，但脚底基线稳定，不在帧内跨格。
```

### 2.3 attack_light

```text
文件：spearman_attack_light.png
单帧：512 × 512
帧数：8
fps：12 - 15
loop：false
hit_frame：5
fx：pierce_streak
impact_offset：[120, -60]
recovery_to：idle
要求：中平直刺，枪尖运动方向清楚，命中帧在枪尖最接近敌人的一帧。
```

### 2.4 guard

```text
文件：spearman_guard.png
单帧：512 × 512
帧数：6
fps：8 - 10
loop：false
active_frame：3
fx：guard_flash
recovery_to：idle
要求：回枪成圆或横枪架势，防守轮廓明确。
```

### 2.5 hit

```text
文件：spearman_hit.png
单帧：512 × 512
帧数：5
fps：12 - 15
loop：false
recovery_to：idle
要求：短促受击，身体后仰但脚底不跳。
```

### 2.6 break

```text
文件：spearman_break.png
单帧：512 × 512
帧数：8
fps：10 - 12
loop：false
recovery_to：idle
要求：破势失衡，枪杆下坠，身体重心明显丢失。
```

---

## 3. spearman.meta.json 目标结构

当正式动作 PNG 到位后，meta 应从旧 sheet 引用改为：

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
      "recovery_to": "idle"
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

---

## 4. AI 生成 Prompt

### 4.1 通用约束

```text
Chinese wuxia spearman pixel art character, transparent background, 512x512 pixels per frame, horizontal sprite sheet, consistent character scale, consistent foot anchor, feet stay on the same baseline, same costume in every frame, same spear in every frame, no camera movement, no perspective change, no extra characters, no duplicated character copies, clean silhouette, readable weapon motion, no background, no cropped feet.
```

### 4.2 idle

```text
A Chinese wuxia spearman pixel art character standing in a calm combat idle pose.
8 frames horizontal sprite sheet, 512x512 pixels per frame, transparent background.
Subtle breathing motion, slight spear movement, stable feet baseline.
Same costume, same spear, same body proportions in every frame.
Clean silhouette, dark martial arts fantasy mood.
No background, no duplicated characters, no cropped feet, no perspective shift.
```

### 4.3 move_forward

```text
A Chinese wuxia spearman pixel art character stepping forward into fighting distance.
6 frames horizontal sprite sheet, 512x512 pixels per frame, transparent background.
Forward pressure, controlled footwork, spear kept ready.
Feet stay on the same baseline, consistent foot anchor, no foot sliding outside the frame.
Same costume, same spear, same body proportions in every frame.
No background, no duplicated characters, no cropped feet, no perspective shift.
```

### 4.4 attack_light

```text
A Chinese wuxia spearman pixel art character performing a straight spear thrust attack.
8 frames horizontal sprite sheet, 512x512 pixels per frame, transparent background.
Frame sequence: anticipation, forward thrust, full extension impact, recovery.
The spear tip moves clearly forward in a straight line.
Cold blue-white martial energy accent at the impact frame.
Feet stay on the same baseline, consistent foot anchor, no foot sliding.
Same costume, same spear, same body proportions in every frame.
No background, no duplicated characters, no cropped feet, no perspective shift.
```

### 4.5 guard

```text
A Chinese wuxia spearman pixel art character performing a spear guard stance.
6 frames horizontal sprite sheet, 512x512 pixels per frame, transparent background.
The spear forms a defensive circle or horizontal guard line.
Stable grounded stance, clear defensive silhouette.
Feet stay on the same baseline, consistent foot anchor.
Same costume, same spear, same body proportions in every frame.
No background, no duplicated characters, no cropped feet, no perspective shift.
```

### 4.6 hit

```text
A Chinese wuxia spearman pixel art character receiving a hit and recoiling shortly.
5 frames horizontal sprite sheet, 512x512 pixels per frame, transparent background.
Short impact reaction, body leans backward, spear remains in hand.
Feet remain close to the same baseline, no cropped feet.
Same costume, same spear, same body proportions in every frame.
No background, no duplicated characters, no perspective shift.
```

### 4.7 break

```text
A Chinese wuxia spearman pixel art character losing posture after being broken.
8 frames horizontal sprite sheet, 512x512 pixels per frame, transparent background.
The spear drops downward, body loses balance, strong stagger but not falling out of frame.
Feet stay visible and close to the same baseline.
Same costume, same spear, same body proportions in every frame.
No background, no duplicated characters, no cropped feet, no perspective shift.
```

---

## 5. 校验命令

动作包到位后，必须依次跑：

```bash
python3 tools/validate_actor_meta.py assets/pixel_battle/actors/spearman/spearman.meta.json
python3 tools/validate_actor_sheet.py assets/pixel_battle/actors/spearman/spearman.meta.json
python3 tools/validate_actor_bundle.py assets/pixel_battle/actors/spearman
python3 tools/validate_art_assets.py
```

Web 验收：

```bash
rm -rf build/web build/web.zip
./tools/build_and_serve_web.sh
```

访问：

```text
http://127.0.0.1:8060
```

---

## 6. Web 验收清单

```text
[ ] spearman idle 不快速乱跳
[ ] move_forward 播放后能回 idle
[ ] attack_light 命中帧触发 pierce_streak
[ ] guard 能看到明确防守姿态
[ ] hit 受击反馈短促明确
[ ] break 破势反馈和普通 hit 有明显区别
[ ] 脚底不漂移、不裁脚
[ ] 气泡仍绑定角色头顶
[ ] 敌方角色身份不被影响
[ ] 旧三帧 fallback 仍可用
[ ] Web 构建无 GDScript 错误
```

---

## 7. 当前下一步

```text
1. 先产出 spearman_idle / attack_light / guard / hit / break / move_forward 六张 PNG；
2. 替换 spearman.meta.json 的 file / frames / fps；
3. 跑 actor bundle 校验；
4. Web 验收；
5. 通过后复制链路到 enemy_spearman。
```
