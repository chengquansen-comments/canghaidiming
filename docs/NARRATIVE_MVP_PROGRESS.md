# 《大明之沧海嘀鸣》叙事 MVP 进度看板

> 当前分支：`feature/symmetry-gameplay`  
> 当前阶段：压缩叙事已从文档进入独立 Demo 实装。  
> 核心原则：不扩写剧情，不重构战斗，不改 Web 外壳，先把“短镜头链 + 三变量 + 单局旧案闭环”跑通。

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

不做完整武官人生，不做多章节，不做长篇对白。

---

## 2. 已完成文档

### 2.1 压缩脚本

```text
docs/MVP_NARRATIVE_SCRIPT_COMPRESSED.md
```

作用：

```text
把开局压成 2–3 分钟极短镜头链；
把每个地图节点压成 1 句旁白 + 2 句对白 + 2–3 个选择；
保留完整旧案闭环；
作为当前叙事实装主参考。
```

### 2.2 完整脚本备份

```text
docs/MVP_NARRATIVE_SCRIPT.md
```

作用：

```text
作为扩展参考；
后续不再按该文档增加叙事密度；
当前实现以 compressed 版为准。
```

### 2.3 美术配套

```text
docs/CHARACTER_IMAGE_PROMPTS_STORY.md
docs/SCENE_IMAGE_PROMPTS_STORY.md
docs/MVP_SINGLE_RUN_ART_COMPLETION_PLAN.md
```

作用：

```text
为叙事 MVP 的人物立绘、场景背景、单局美术闭环提供资产制作清单；
当前还未接入运行时，仅作为资产生产和后续接入依据。
```

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
输出变量显示文本。
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
展示结局。
```

### 3.4 独立测试场景

```text
scenes/NarrativeDemo.tscn
```

用途：

```text
单独运行叙事 MVP；
暂不替换 MainVisual.tscn；
暂不接入真实战斗；
暂不影响 Web 主构建路径。
```

---

## 4. 已完成提交记录

```text
ac07cac6c1347678c7f47047fe0b75b28f0278b0  Add compressed MVP narrative script
dc815aa0186e41107b0d1c7dc6366183684b5bc6  Add compressed MVP narrative data
9062ee7bba22d47128175e1a5740cc06af851dff  Add narrative state runtime
c5ab27b03a888eabbb2f317663cdec613a061df6  Add compressed narrative demo controller
da1e5b08bb3d3ccf5e293940086d4a33f6e8e901  Add compressed narrative demo scene
113ddb5ff811798d8fcb0abec325a38040116a37  Add narrative implementation progress notes
```

---

## 5. 当前状态判断

### 5.1 已经完成

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
```

### 5.2 尚未验收

```text
[ ] 本地运行 NarrativeDemo.tscn 无 GDScript 编译错误
[ ] 序章可从头点到“该出山了”
[ ] 节点选择可正常推进
[ ] 三变量显示正确
[ ] Boss 后可进入军门压案
[ ] 上报 / 掩盖 / 私查 / 借势可按条件出现
[ ] 结局能正常显示
```

### 5.3 尚未实装

```text
[ ] 真实肉鸽地图 UI
[ ] 与现有战斗场景的胜利回调
[ ] P0 背景图显示
[ ] P0 人物立绘显示
[ ] 旧物图显示
[ ] Web 主入口接入策略
```

---

## 6. 当前风险

### 风险一：GDScript 编译风险

当前新增脚本尚未经过本地 Godot 编译验证。重点风险点：

```text
JSON 字段类型转换；
Array / Dictionary 静态类型；
PackedStringArray 从 Array 转换；
RichTextLabel / Label 属性在当前 Godot 版本中的兼容性；
信号绑定 bind 的参数类型。
```

处理原则：

```text
先修到 NarrativeDemo.tscn 可运行；
不要同时改战斗主控制器；
不要在编译未过前接 MainVisual。
```

### 风险二：叙事路径过线性

当前推荐路径能闭环，但还不是完整肉鸽地图。

处理原则：

```text
先接受线性流程；
验证压缩叙事节奏；
下一刀再加地图节点 UI 和分支。
```

### 风险三：战斗节点只是占位

当前 battle / elite / boss 节点只显示 encounter_id，不会真的进入战斗。

处理原则：

```text
先验证叙事状态机；
再接战斗胜利回调；
不要为了叙事提前大改战斗规则。
```

---

## 7. 下一刀执行清单

### Step 1：本地编译验收

```text
打开 scenes/NarrativeDemo.tscn
运行当前场景
记录 GDScript 错误
逐个修复
```

通过标准：

```text
[ ] 场景能打开
[ ] 点击“继续”不报错
[ ] 序章能完整播放
[ ] 进入军令节点
```

### Step 2：叙事流程验收

验证推荐路径：

```text
序章
→ 军令：问旧案
→ 海边伏击：搜身留证
→ 明制火器：私下留证
→ 押运官：私藏名册
→ 夜半磨刀：问旧案
→ Boss：查看火器箱
→ 军门压案：据实上报 / 藏下一份证据
```

通过标准：

```text
[ ] 旧案线索 >= 3 时出现“据实上报”
[ ] 旧案线索 >= 2 时出现“藏下一份证据”
[ ] 未经过海商宴时不出现“拿证据换船粮”
[ ] 变量变化符合按钮显示
```

### Step 3：增加最小地图 UI

先做一张静态路线图，不做复杂生成算法：

```text
军令
→ 海边伏击 / 渔村残火
→ 明制火器 / 海商宴
→ 押运官 / 欠饷营 / 夜半磨刀
→ Boss
→ 军门压案
```

展示要求：

```text
六类节点图标；
当前节点高亮；
已走节点变暗；
未开放节点半透明；
节点点击进入 current_node。
```

### Step 4：接 P0 美术占位

先显示背景路径对应图片，图片不存在时显示文本占位，不阻塞运行。

优先：

```text
prologue_burning_village.png
prologue_master_blocks_blade.png
prologue_ten_years_later.png
node_military_order.png
node_beach_ambush.png
node_ming_firearms.png
boss_wakou_wrecked_ship.png
ending_military_office_coverup.png
```

### Step 5：接战斗胜利回调

当前不要求真实切场景，先设计接口：

```text
NarrativeState.current_node.combat
→ battle encounter_id
→ battle_win
→ 回到当前 node 的战后 choices
```

---

## 8. 对 Codex 的下一步指令

```text
请基于 scenes/NarrativeDemo.tscn、scripts/narrative/narrative_state.gd、scripts/narrative/narrative_demo_controller.gd 做最小修复与验收。目标是让 NarrativeDemo.tscn 在 Godot Web 项目中无编译错误运行。不要改 MainVisual.tscn，不要改 battle_controller，不要改 web_shell.html。若出现类型错误，只做局部修复。验收路径为：序章完整播放 → 军令节点 → 节点选择 → 三变量变化 → Boss → 军门压案 → 结局。
```

---

## 9. 当前一句话结论

```text
叙事 MVP 已完成“脚本压缩 → 数据化 → 状态机 → 独立 Demo 场景”的第一闭环；下一步不是扩写剧情，而是本地跑通 NarrativeDemo.tscn，并在不影响战斗主线的前提下补最小地图 UI 和美术占位。
```
