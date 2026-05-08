# v3.9 generated minimal playable round

## 阶段目标
在 v3.8 可呈现战斗基础上，验证 generated node 进入最小可玩轮次：轮次初始化成功、可输入就绪、敌方意图候选可读、玩家卡候选可用。

## 关键边界
- fallback_policy 固定 legacy。
- 非 generated node 继续 legacy。
- generated card_pool 仅候选映射，不覆盖 CardData。
- narrative 仅 key/hook，不生成正文。
- route_gate 仅候选，不改变正式分流。
- 不写 story_battles，不写 final combat_result。

## 验收命令
```bash
godot --headless --path . --script tools/content_engine/generated_minimal_playable_round_probe.gd
python3 tools/content_engine/generated_minimal_playable_round_validator.py
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
python3 -m py_compile \
  tools/content_engine/generated_minimal_playable_round_validator.py \
  tools/content_engine/content_engine_check.py \
  tools/content_engine/content_engine_acceptance_runner.py \
  tools/content_engine/content_engine_acceptance_validator.py
git diff --check
```
