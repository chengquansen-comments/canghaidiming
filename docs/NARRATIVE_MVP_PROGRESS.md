# 《大明之沧海嘀鸣》叙事 MVP 进度看板

> 当前分支：`feature/symmetry-gameplay`  
> 当前阶段：压缩叙事已推进到“静态分叉地图展示层 + 地图点击选路接口”。  
> 核心原则：剧情 MVP 入口和现有选角色战斗入口分开；不扩写剧情，不重构战斗，不改 Web 外壳结构；先把短镜头链、三变量、单局旧案闭环、路线感、中文显示、最小地图表现、视觉占位和战斗接口跑通。

---

## 1. 当前目标

叙事 MVP 只验证一件事：

```text
玩家能在一局内走完：
倭寇袭村
→ 师父救命
→ 十年后出山
→ 军令巡海
→ 明制火器
→ 押运官 / 旧案碎片
→ Boss 灭口
→ 军门压案
→ 上报 / 掩盖 / 私查 / 借势
```

入口与流程目标：

```text
剧情 MVP：进入 NarrativeDemo.tscn
战斗测试：进入现有 MainVisual.tscn / MainText.tscn
叙事 Demo：显示压缩序章、当前节点、三变量、推荐路线、已走节点、结局入口
中文显示：剧情侧统一走 NarrativeFontHelper，内部复用战斗测试的 BattleFontHelper / cjk_font.ttf 逻辑
地图表现：读取静态分叉地图布局 JSON，按六列展示军令 / 初遇 / 疑点 / 压迫 / 破船 / 军门
地图选路：接口层已完成，后续 UI 点击必须走原有 choice / choose 逻辑，不绕过叙事状态机
背景表现：图片存在则显示，不存在则显示明确占位文本，不阻塞 Web 运行
人物表现：立绘存在则显示，不存在则显示角色名 / 路径占位，不阻塞 Web 运行
旧物表现：旧物图存在则显示，不存在则显示旧物名 / 路径占位，不阻塞 Web 运行
战斗接口：NarrativeDemo 内只做占位按钮，不强切 MainVisual，不改 battle_controller
```

---

## 2. 已完成文档

```text
docs/MVP_NARRATIVE_SCRIPT_COMPRESSED.md
docs/MVP_NARRATIVE_SCRIPT.md
docs/CHARACTER_IMAGE_PROMPTS_STORY.md
docs/SCENE_IMAGE_PROMPTS_STORY.md
docs/MVP_SINGLE_RUN_ART_COMPLETION_PLAN.md
```

当前实现以 `MVP_NARRATIVE_SCRIPT_COMPRESSED.md` 为准，完整脚本只作扩展参考。

---

## 3. 已完成实装

### 3.1 压缩叙事 JSON

```text
data/narrative/mvp_compressed_narrative.json
```

已包含：

```text
序章极短镜头链；
三变量：军功 / 清望 / 旧案线索；
主要节点：军令、海边伏击、渔村残火、明制火器、押运官、欠饷营、海商宴、夜半磨刀、Boss、军门压案；
最终四选一：上报 / 掩盖 / 私查 / 借势；
结局：上报、掩盖、私查、借势、沉默。
```

### 3.2 静态分叉地图布局 JSON

```text
data/narrative/mvp_static_map_layout.json
```

已包含：

```text
布局 ID：mvp_static_branch_map_v1
列结构：军令 / 初遇 / 疑点 / 压迫 / 破船 / 军门
节点结构：military_order、beach_ambush、burnt_village、ming_firearm、merchant_banquet、transport_officer、night_sharpening、mutiny_camp、wakou_boss、military_coverup
边结构：从军令分叉，经疑点和压迫节点收束到 Boss，再进入军门压案
节点类型图标：battle / elite / event / camp / relic / boss / ending_gate
状态标记：current / visited / available / locked
```

用途定位：

```text
只用于地图 UI 表现和后续可点击节点升级；
不改变 mvp_compressed_narrative.json 的推进逻辑；
不做随机地图生成；
不影响当前 narrative-only 路径。
```

### 3.3 静态地图布局读取器

```text
scripts/narrative/narrative_static_map_layout.gd
```

已支持：

```text
读取 data/narrative/mvp_static_map_layout.json；
解析 columns / edges；
建立 node_to_column 索引；
建立 outgoing_edges / incoming_edges 索引；
提供 previous_nodes / next_nodes；
供 NarrativeDemo 渲染分叉地图和判断可达节点。
```

### 3.4 叙事状态机

```text
scripts/narrative/narrative_state.gd
```

已支持：

```text
读取叙事 JSON；
初始化变量；
推进序章 step；
读取当前 node；
过滤 requires / requires_flag；
应用变量 delta；
记录 flags，例如 merchant_deal；
进入 ending；
输出变量显示文本；
记录 visited_node_ids；
输出推荐路线 route_text；
输出当前节点状态 node_status_text；
按 next_node_id 查找可用 choice；
can_choose_next_node(next_node_id)；
choose_next_node(next_node_id)，内部仍走 available_choices → choose(index)。
```

### 3.5 地图点击选路 Router

```text
scripts/narrative/narrative_map_click_router.gd
```

已支持：

```text
can_click_node(narrative, node_id)；
click_node(narrative, node_id)；
click_hint(narrative, node_id)：当前节点 / 已走过 / 可前往 / 未开放；
所有点击仍通过 NarrativeState.choose_next_node；
不会绕过 requires / requires_flag / delta / flags / ending 逻辑。
```

### 3.6 独立 Demo Controller

```text
scripts/narrative/narrative_demo_controller.gd
```

已支持：

```text
运行时构建最小 UI；
展示序章 step；
展示节点标题 / 类型 / 背景路径 / 旁白 / 对白；
展示选择按钮；
展示变量变化；
展示结局；
读取 mvp_static_map_layout.json；
按 columns 渲染静态分叉地图；
显示军令 / 初遇 / 疑点 / 压迫 / 破船 / 军门六列；
显示节点卡片；
当前节点高亮；
已走节点变色；
可达节点标记为 ◎；
未到节点显示 ○；
展示 P0 背景图区域；
展示 P0 人物立绘区域；
展示旧物图占位；
在 battle / elite / boss 节点展示战斗桥接面板；
战斗桥接面板支持“请求战斗”和“视为胜利继续”；
请求战斗时展示 node_id / encounter_id / enemies payload；
视为胜利继续时不切 MainVisual，只回到当前节点战后选择；
通过 NarrativeFontHelper.enforce(self) 统一应用中文字体；
动态刷新节点、选择按钮、结局页后重复应用字体，避免新增控件中文乱码。
```

> 注意：地图点击 UI 还未接到 controller，当前只完成接口层，下一刀接 UI 点击。

### 3.7 中文字体 Helper

```text
scripts/narrative/narrative_font_helper.gd
```

职责：

```text
作为叙事侧字体统一入口；
内部复用 scripts/visual/battle_font_view.gd；
保持剧情 MVP 与战斗测试使用同一套 CJK 字体链路；
后续叙事 UI 新增控件时只需要调用 NarrativeFontHelper.enforce(root)。
```

### 3.8 战斗回调桥接接口

```text
scripts/narrative/narrative_combat_bridge.gd
```

已支持：

```text
从当前叙事节点读取 combat 字段；
生成 battle payload：node_id / node_title / node_type / encounter_id / enemies；
发出 battle_requested(payload) 信号；
预留 battle_finished(payload) 信号；
提供 resolve_win(extra) / resolve_loss(extra)；
保留 pending_payload；
不强制切换 MainVisual；
不修改 battle_controller；
不改变 narrative-only 路径。
```

### 3.9 独立测试场景

```text
scenes/NarrativeDemo.tscn
```

用途：

```text
单独运行叙事 MVP；
暂不替换 MainVisual.tscn；
暂不接入真实战斗；
暂不影响现有战斗测试场景。
```

### 3.10 入口分流

已更新：

```text
scripts/web_runtime_launcher.gd
scripts/main_mode_launcher.gd
```

Web 入口：

```text
进入剧情 MVP → scenes/NarrativeDemo.tscn
进入战斗测试 → scenes/MainVisual.tscn
重新加载当前页
```

桌面开发入口：

```text
进入剧情 MVP → scenes/NarrativeDemo.tscn
进入字符版战斗 → scenes/MainText.tscn
进入视觉版战斗 → scenes/MainVisual.tscn
```

说明：

```text
未修改 MainVisual.tscn；
未修改 battle_controller；
未替换当前选角色战斗入口；
Web smoke_battle 参数仍保留自动进入战斗测试；
新增 narrative_mvp 参数可自动进入剧情 MVP。
```

---

## 4. 验收状态

### 4.1 用户已验收通过

```text
[x] 剧情 MVP 中文不乱码
[x] 入口分流可用
[x] NarrativeDemo 可进入
```

### 4.2 当前仍需继续验收

```text
[ ] 静态分叉地图六列显示正常
[ ] 当前节点高亮
[ ] 已走节点变色
[ ] 可达节点显示 ◎
[ ] 未到节点显示 ○
[ ] 地图点击接口文件可编译
[ ] NarrativeState.choose_next_node 可正常按 next 匹配 choice
[ ] P0 背景区域图片存在时可显示
[ ] P0 背景资源不存在时可显示占位文本
[ ] P0 立绘资源存在时可显示
[ ] P0 立绘资源不存在时可显示角色名 / 路径占位
[ ] 旧物图资源存在时可显示
[ ] 旧物图资源不存在时可显示旧物名 / 路径占位
[ ] 战斗桥接接口文件可编译
[ ] 战斗节点 payload 字段正确：node_id / encounter_id / enemies
[ ] battle / elite / boss 节点显示“请求战斗 / 视为胜利继续”
[ ] 点击“请求战斗”能生成 payload
[ ] 点击“视为胜利继续”后仍显示当前节点战后选择
[ ] 不跳 MainVisual
[ ] 不改 battle_controller
[ ] narrative-only 路径仍可完整走通
[ ] 序章可从头点到“该出山了”
[ ] 节点选择可正常推进
[ ] 三变量显示正确
[ ] Boss 后可进入军门压案
[ ] 上报 / 掩盖 / 私查 / 借势可按条件出现
[ ] 结局能正常显示
```

---

## 5. 已完成提交记录

```text
ac07cac6c1347678c7f47047fe0b75b28f0278b0  Add compressed MVP narrative script
dc815aa0186e41107b0d1c7dc6366183684b5bc6  Add compressed MVP narrative data
9062ee7bba22d47128175e1a5740cc06af851dff  Add narrative state runtime
c5ab27b03a888eabbb2f317663cdec613a061df6  Add compressed narrative demo controller
da1e5b08bb3d3ccf5e293940086d4a33f6e8e901  Add compressed narrative demo scene
113ddb5ff811798d8fcb0abec325a38040116a37  Add narrative implementation progress notes
156d04e86c455b153d864b6f34f6557da399d4c2  Add narrative MVP progress tracker
8d69a2c06bd0f93cadc5bbad9d7544787e06b687  Refresh narrative implementation progress
6213ecf242a4a8d08bc4a9459fa14ef46d8f5a22  Add separate narrative MVP entry to desktop launcher
0bd6542f2c58c8e057015a28f7a73d03d905a848  Refresh narrative MVP progress after entry split
e78ebbaa11775a1d944944ac6b706f113b57243f  Add MVP narrative route state
8955ac6add7723e7b9ecf0905217bed3a65e3708  Add route overview to narrative demo
05c16bf0afda79b5bf182cda658e005bf3e1136c  Apply battle CJK font handling to narrative demo
d91a2bb3c3d12087af10145aabf3e632650a888a  Use narrative font helper in narrative demo
cf820324e9f05e7c765ad8a2464ed1f34a929bdd  Add minimal narrative map strip UI
a456bb1dd122b6823dcf98736461c73b579f79c2  Refresh narrative progress after map strip
92515b04cab816490edb1ce1d8f28f38e4807d21  Add P0 narrative background placeholder display
1ec55f51dad90705c99b56fe77f6bea64aeb566b  Refresh narrative progress after P0 background placeholders
e75f6f700e18cf3c777f56b246a76ab07526f4d1  Add P0 narrative portrait placeholder display
1f35d7100f0519a30c31108e0508f395755a711c  Refresh narrative progress after portrait placeholders
053c9b083d3906b437c6d6392f1de6dd5843cfd5  Add MVP relic placeholder display
6a552c0f40bb2be5b81cb8bf6b575f94f4eaedae  Add narrative combat bridge interface
f5e68ecc597af7af44bf2e0cbbcfaeadf9515dbb  Connect narrative combat bridge to demo
22da1479f37a8de22ff84c38df0576dfe44d0a49  Refresh narrative progress after demo combat bridge
8be4aa9e342f21ce9a436e8830dc242671284967  Add MVP static narrative map layout
e4da062e39f130eedf21d1c1cf44f79828768e06  Refresh narrative progress after static map layout data
22005f41766ab3a4ab8e9522d07d22a5af25d699  Add narrative static map layout loader
04297f2b61f98cda12c7067bbbb813857c64077e  Render static branch map layout in narrative demo
3a2b04f56cfce1ab599e39b4a278c2dda624ab60  Refresh narrative progress after branch map rendering
d9202d91e55bd32614171b546d7cd974afaa5ffa  Add narrative next-node choice helper
ee7fbb796b5cd7be7e39f8f13adcf80f5fbb2b03  Add narrative map click router
```

---

## 6. 当前状态判断

### 6.1 已经完成

```text
[x] 压缩叙事脚本定稿
[x] 叙事 JSON 数据化
[x] 静态分叉地图布局数据化
[x] 静态地图布局读取器
[x] NarrativeDemo 读取布局 JSON 渲染六列分叉地图
[x] 地图点击选路状态机接口
[x] 地图点击 Router
[x] 三变量数据结构
[x] choice delta 机制
[x] requires / requires_flag 机制
[x] merchant_deal flag
[x] ending 入口
[x] 独立 Demo 场景
[x] 不影响现有战斗主场景
[x] Web 入口区分：剧情 MVP / 战斗测试
[x] 桌面入口区分：剧情 MVP / 字符战斗 / 视觉战斗
[x] P0 背景图显示占位：图片存在则显示，不存在则占位
[x] P0 人物立绘显示占位：图片存在则显示，不存在则角色名 / 路径占位
[x] 旧物图显示占位：图片存在则显示，不存在则旧物名 / 路径占位
[x] 战斗回调桥接接口：NarrativeCombatBridge
[x] NarrativeDemo 战斗桥接占位按钮：请求战斗 / 视为胜利继续
[x] 潜在数组强转风险局部修复：敌人列表不再使用 PackedStringArray 强转
[x] 剧情 MVP 中文字体修复：复用 BattleFontHelper / cjk_font.ttf
[x] 新增 NarrativeFontHelper，叙事侧字体入口收口
```

### 6.2 尚未实装

```text
[ ] NarrativeDemo 节点卡片点击调用 NarrativeMapClickRouter
[ ] 与现有战斗场景的真实胜利回调
```

---

## 7. 当前风险

### 风险一：地图点击 UI 尚未接入

当前已完成状态机和 Router，但还没有让节点卡片点击触发选路。

处理原则：

```text
下一刀只接 UI 点击；
点击可前往节点时调用 NarrativeMapClickRouter.click_node；
不可点击节点只提示原因；
仍然不做随机地图生成；
仍然不绕过 choice 逻辑。
```

### 风险二：静态分叉地图需要 Web 验收

当前 NarrativeDemo 已读取 `mvp_static_map_layout.json` 并渲染六列地图，但尚未 Web 验收。

处理原则：

```text
验证六列展示是否可读；
确认 1600×1000 下不挤压正文；
确认当前 / 已走 / 可达 / 未到状态准确。
```

### 风险三：真实战斗仍未接入

当前 battle / elite / boss 节点只做 bridge 占位。

处理原则：

```text
先验收占位桥接；
再接真实战斗胜利回调；
不要为了叙事大改战斗规则。
```

---

## 8. 下一刀执行清单

### Step 1：接 NarrativeDemo 地图节点点击

```text
节点卡片改为 Button 或可点击控件
当前节点：提示“当前节点”
已走节点：提示“已走过”
可前往节点：调用 NarrativeMapClickRouter.click_node
未开放节点：提示“未开放”
点击成功后刷新 node / map / choices / variables
```

通过标准：

```text
[ ] 点击 ◎ 可达节点能推进到对应节点
[ ] 点击 ○ 未开放节点不推进，只提示
[ ] 点击 ● 已走节点不推进，只提示
[ ] 点击 ▶ 当前节点不推进，只提示
[ ] 推进仍走 NarrativeState.choose_next_node
[ ] requires / delta / flags 仍由原 choice 逻辑处理
```

### Step 2：验收 NarrativeDemo 战斗桥接占位

```text
进入剧情 MVP
走完序章
进入海边伏击 / 押运官 / Boss 等战斗节点
观察战斗桥接面板
点击“请求战斗”
点击“视为胜利继续”
继续选择战后处理
```

### Step 3：后续真实接战斗

```text
NarrativeState.current_node.combat
→ NarrativeCombatBridge.build_payload
→ MainVisual / 战斗场景
→ battle_win
→ 回到当前 node 战后 choices
```

原则：

```text
正式接入前，先梳理 MainVisual 的启动参数和战斗结束信号；
不要直接改战斗规则；
不要破坏现有选角色战斗测试入口。
```

---

## 9. 对 Codex 的下一步指令

```text
请把 NarrativeDemo 的静态分叉地图节点卡片改成可点击控件，并接入 scripts/narrative/narrative_map_click_router.gd。只有 click_hint 为“可前往”的节点允许推进；推进必须调用 NarrativeMapClickRouter.click_node，并最终走 NarrativeState.choose_next_node，不允许绕过 choice / requires / delta / flags 逻辑。当前节点、已走节点、未开放节点点击后只提示，不推进。不要改变 mvp_compressed_narrative.json 的推进逻辑，不要做随机地图生成，不要改 battle_controller，不要改 MainVisual.tscn，不要重构 web_shell.html。
```

---

## 10. 当前一句话结论

```text
叙事 MVP 已完成“静态分叉地图展示层 → 状态机选路接口 → 地图点击 Router”；下一步抓重点把节点卡片点击接到 NarrativeDemo，让地图成为真正可点的选路入口，但仍保持所有推进走原有 choice 逻辑。
```
