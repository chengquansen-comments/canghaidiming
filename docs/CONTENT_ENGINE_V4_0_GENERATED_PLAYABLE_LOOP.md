# v4.0 generated playable battle loop

## 目标
在 generated battle 可进入基础上，完成一次最小玩家可操作循环：选择动作、执行动作标记、产出 reward pending/settlement candidate。

## 边界
- fallback_policy=legacy。
- 非 generated node 仍 legacy。
- 不覆盖 CardData，不改 story_battles，不写 final combat_result。
- narrative 仅 key/hook。
- route_gate 仅 candidate，不改正式分流。

## 验收命令
```bash
godot --headless --path . --script tools/content_engine/generated_playable_loop_probe.gd
python3 tools/content_engine/generated_playable_loop_validator.py
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
python3 -m py_compile \
  tools/content_engine/generated_playable_loop_validator.py \
  tools/content_engine/content_engine_check.py \
  tools/content_engine/content_engine_acceptance_runner.py \
  tools/content_engine/content_engine_acceptance_validator.py
git diff --check
```
