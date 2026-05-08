# v3.8 generated playable battle scene 冒烟接入

## 阶段目标
本阶段在不改动战斗结算核心的前提下，把 generated node 选择结果接到现有 battle controller 初始化链路，验证至少一个 generated node 可以进入“可展示战斗”的冒烟就绪状态。

## 关键约束
- fallback_policy 固定为 legacy。
- 非 generated node 继续走 legacy。
- generated card_pool 仅作为上下文候选，不覆盖 CardData。
- narrative 仅 key/hook，不生成正文。
- route_gate 仅候选记录，不改变正式分流。
- 不写 story_battles，不写 final combat_result。

## 冒烟路径
1. 读取 generated player node pool。
2. 选择一个 generated node。
3. 构造 playable battle entry。
4. 调用现有 battle context 入口脚本完成上下文挂接。
5. 输出 scene/controller 初始化可用状态与 domain 计数。

## 验收命令
```bash
godot --headless --path . --script tools/content_engine/generated_playable_battle_scene_probe.gd
python3 tools/content_engine/generated_playable_battle_scene_validator.py
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
python3 -m py_compile \
  tools/content_engine/generated_playable_battle_scene_validator.py \
  tools/content_engine/content_engine_check.py \
  tools/content_engine/content_engine_acceptance_runner.py \
  tools/content_engine/content_engine_acceptance_validator.py
git diff --check
```
