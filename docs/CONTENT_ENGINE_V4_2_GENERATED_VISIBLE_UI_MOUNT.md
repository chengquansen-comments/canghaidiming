# v4.2 generated visible UI mount

## 目标
把 generated content 状态挂到实际可见 UI 调试文本入口，运行游戏时可直接看到 Generated Content 状态与关键字段。

## 显示字段
- Generated Content: ON/OFF
- Node
- Battle Slot
- Enemy Deck
- Card Pool
- Reward
- Narrative Keys
- Route Gates
- Action/Input
- Reward Pending
- Fallback

## 边界
- fallback_policy=legacy
- 不覆盖 CardData，不写 story_battles，不写 final combat_result
- narrative 仅 key/hook，route_gate 仅 candidate

## 验收命令
```bash
godot --headless --path . --script tools/content_engine/generated_visible_ui_mount_probe.gd
python3 tools/content_engine/generated_visible_ui_mount_validator.py
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
python3 -m py_compile \
  tools/content_engine/generated_visible_ui_mount_validator.py \
  tools/content_engine/content_engine_check.py \
  tools/content_engine/content_engine_acceptance_runner.py \
  tools/content_engine/content_engine_acceptance_validator.py
git diff --check
```
