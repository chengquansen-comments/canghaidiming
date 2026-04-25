# 《大明之沧海嘀鸣》叙事 MVP 进度看板

> 当前分支：`feature/symmetry-gameplay`  
> 当前阶段：压缩叙事已推进到“验收通过 + 地图卡片 UI + P0 背景占位 + P0 人物立绘占位”。  
> 核心原则：剧情 MVP 入口和现有选角色战斗入口分开；不扩写剧情，不重构战斗，不改 Web 外壳结构；先把短镜头链、三变量、单局旧案闭环、路线感、中文显示、最小地图表现、背景占位和人物占位跑通。

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
地图表现：从文字路线条升级为横向节点卡片
背景表现：图片存在则显示，不存在则显示明确占位文本，不阻塞 Web 运行
人物表现：立绘存在则显示，不存在则显示角色名 / 路径占位，不阻塞 Web 运行
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

### 3.2 叙事状态机

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
输出当前节点状态 node_status_text。
```

### 3.3 独立 Demo Controller

```text
scripts/narrative/narrative_demo_controller.gd
```

已支持：

```text
运行时构建最小 UI；
展示序章 step；
展示节点标题 / 类型 / 背景路径 / 旁白 / 对白；
展示战斗占位 encounter_id；
展示选择按钮；
展示变量变化；
展示结局；
展示路线条：● 已走 / ▶ 当前 / ○ 未到；
展示横向节点卡片：节点标题、节点类型、已走/当前/未到状态；
展示 P0 背景图区域；
序章 step 可按 id 映射到 P0 序章背景；
节点可读取 background 字段并尝试加载对应背景；
图片不存在时显示占位文本，不阻塞运行；
展示 P0 人物立绘区域；
序章 step 可按 id 映射幼年主角、师父、成年主角等立绘；
节点可按 speaker 映射军门上官、Boss、海商、押运官、兵变营头等立绘；
立绘不存在时显示角色名 / 路径占位，不阻塞运行；
通过 NarrativeFontHelper.enforce(self) 统一应用中文字体；
动态刷新节点、选择按钮、结局页后重复应用字体，避免新增控件中文乱码。
```

### 3.4 中文字体 Helper

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

### 3.5 独立测试场景

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

### 3.6 入口分流

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
[ ] 横向节点卡片 UI 在 Web 下显示正常
[ ] 节点卡片当前 / 已走 / 未到状态准确
[ ] P0 背景区域图片存在时可显示
[ ] P0 背景资源不存在时可显示占位文本
[ ] P0 立绘资源存在时可显示
[ ] P0 立绘资源不存在时可显示角色名 / 路径占位
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
```

---

## 6. 当前状态判断

### 6.1 已经完成

```text
[x] 压缩叙事脚本定稿
[x] 叙事 JSON 数据化
[x] 三变量数据结构
[x] choice delta 机制
[x] requires / requires_flag 机制
[x] merchant_deal flag
[x] ending 入口
[x] 独立 Demo 场景
[x] 不影响现有战斗主场景
[x] Web 入口区分：剧情 MVP / 战斗测试
[x] 桌面入口区分：剧情 MVP / 字符战斗 / 视觉战斗
[x] 最小路线 UI：● 已走 / ▶ 当前 / ○ 未到
[x] 最小肉鸽地图卡片 UI：节点标题 / 节点类型 / 状态
[x] P0 背景图显示占位：图片存在则显示，不存在则占位
[x] P0 人物立绘显示占位：图片存在则显示，不存在则角色名 / 路径占位
[x] 潜在数组强转风险局部修复：敌人列表不再使用 PackedStringArray 强转
[x] 剧情 MVP 中文字体修复：复用 BattleFontHelper / cjk_font.ttf
[x] 新增 NarrativeFontHelper，叙事侧字体入口收口
```

### 6.2 尚未实装

```text
[ ] 旧物图显示
[ ] 与现有战斗场景的胜利回调
[ ] 真正分叉式肉鸽地图布局
```

---

## 7. 当前风险

### 风险一：背景 + 立绘区域的 Web 适配

当前已新增背景显示区域和右侧立绘区域，仍需验证：

```text
是否挤压正文；
图片不存在时占位是否清楚；
图片存在时比例是否正确；
横向地图卡片 + 背景区域 + 立绘区域 + 正文是否在 1600×1000 下可读。
```

### 风险二：speaker 到立绘的映射仍是最小规则

当前只按 step id 和 speaker 做简单映射。

处理原则：

```text
先跑通 P0 立绘占位；
后续如需要更准，再在 narrative JSON 中增加 portrait 字段；
不要现在扩张数据结构。
```

### 风险三：战斗节点仍是占位

当前 battle / elite / boss 节点只展示 encounter_id。

处理原则：

```text
先把叙事节奏、地图 UI、背景占位、立绘占位跑通；
再接战斗胜利回调；
不要为了叙事大改战斗规则。
```

---

## 8. 下一刀执行清单

### Step 1：验收 P0 背景 + 立绘占位

```text
进入剧情 MVP
走完序章
进入军令节点
逐步推进到明制火器 / Boss / 军门压案
观察背景区域和立绘区域
```

通过标准：

```text
[ ] 背景图片不存在时显示明确占位文本
[ ] 背景图片存在时显示图片
[ ] 立绘图片不存在时显示角色名 / 路径占位
[ ] 立绘图片存在时显示图片
[ ] 正文区域不被挤没
[ ] 地图卡片仍可横向滚动
[ ] 中文不乱码
```

### Step 2：接旧物图显示

优先：

```text
relic_ming_firearm.png
relic_altered_report.png
relic_old_spear_tassel.png
relic_transport_token.png
```

原则：

```text
旧物图存在则显示；
旧物图不存在则显示旧物名占位；
不因为缺图阻塞 Web 运行。
```

### Step 3：预留战斗回调接口

```text
NarrativeState.current_node.combat
→ encounter_id
→ 战斗测试入口
→ battle_win
→ 回到当前 node 战后 choices
```

---

## 9. 对 Codex 的下一步指令

```text
请优先验证 NarrativeDemo.tscn 的 P0 背景和 P0 人物立绘占位显示。当前剧情 MVP 已通过用户验收：入口分流可用，中文不乱码。下一步不要扩写剧情，不要改 battle_controller，不要改 MainVisual.tscn，不要重构 web_shell.html。请验证：序章与节点是否出现背景区域和右侧立绘区域；图片不存在时是否有清晰占位；地图卡片是否仍正常显示；正文是否没有被挤压。验证后再接旧物图显示占位。
```

---

## 10. 当前一句话结论

```text
叙事 MVP 已完成“脚本压缩 → 数据化 → 状态机 → 独立 Demo 场景 → 入口分流 → 中文字体专用 Helper → 最小肉鸽地图卡片 UI → P0 背景占位 → P0 人物立绘占位”；下一步抓重点验收视觉区域，再接旧物图占位和战斗回调接口。
```
