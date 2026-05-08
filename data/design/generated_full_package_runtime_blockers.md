# Full Package Runtime Readiness Blockers

## 终局定义
全生成内容（7 个 domain）正式 enable，并具备可回退的 runtime 挂接能力。

## 当前状态
- battle_slot: formal_enable_ready=false，adapter=false，blocker=缺 battle_slot 正式 runtime adapter 与流程挂接。
- enemy_deck: formal_enable_ready=false，adapter=false，blocker=未证明 generated enemy_deck 可被正式战斗 enemy loader 使用。
- card_pool: formal_enable_ready=false，adapter=false，blocker=未证明可安全映射 CardData。
- reward: formal_enable_ready=false，adapter=true，blocker=shadow/candidate 已通，但正式 enable 仍未放开。
- operation_node: formal_enable_ready=false，adapter=false，blocker=缺 operation node 正式流程挂接。
- narrative: formal_enable_ready=false，adapter=false，blocker=当前仅 key/hook，缺正文策略与正式挂接。
- route_gate: formal_enable_ready=false，adapter=false，blocker=缺 route gate 正式路线逻辑挂接。

## 缺 runtime adapter 的 domain
- battle_slot, enemy_deck, card_pool, operation_node, narrative, route_gate

## 缺 legacy fallback 的 domain
- 当前审计未发现缺失项（均标记为可回退），但尚未完成正式 adapter 级联验证。

## 缺正式流程挂接的 domain
- battle_slot, enemy_deck, card_pool, operation_node, narrative, route_gate

## v2.1 推荐优先项
1. card_pool_to_card_data_mapper
2. enemy_deck_runtime_loader
3. battle_slot_runtime_loader
4. operation_node_runtime_loader / route_gate_runtime_loader
5. narrative_runtime_loader（含正文策略）

## 说明
本次仅 readiness audit，没有导出 runtime，也没有改 Godot 正式流程。
