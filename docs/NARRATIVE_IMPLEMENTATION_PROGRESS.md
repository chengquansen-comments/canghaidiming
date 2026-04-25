# 压缩版叙事实装进度

> 对应脚本：`docs/MVP_NARRATIVE_SCRIPT_COMPRESSED.md`  
> 当前目标：先独立跑通压缩叙事链路，不接管现有战斗规则和 Web 外壳。

---

## 1. 已新增文件

```text
data/narrative/mvp_compressed_narrative.json
scripts/narrative/narrative_state.gd
scripts/narrative/narrative_demo_controller.gd
scenes/NarrativeDemo.tscn
```

---

## 2. 当前实现内容

### 2.1 压缩叙事数据

```text
data/narrative/mvp_compressed_narrative.json
```

包含：

```text
序章极短镜头链
三变量：军功 / 清望 / 旧案线索
节点：军令、海边伏击、渔村残火、明制火器、押运官、欠饷营、海商宴、夜半磨刀、Boss、军门压案
最终四选一：上报 / 掩盖 / 私查 / 借势
小结局：上报、掩盖、私查、借势、沉默
```

### 2.2 叙事运行时状态

```text
scripts/narrative/narrative_state.gd
```

职责：

```text
读取 JSON
初始化三变量
推进序章 step
读取当前 node
过滤可选 choice
应用变量 delta
记录 flags，例如 merchant_deal
进入 ending
输出变量显示文本
```

### 2.3 独立 Demo UI 控制器

```text
scripts/narrative/narrative_demo_controller.gd
```

职责：

```text
构建最小 UI
展示序章 step
展示节点标题 / 类型 / 背景路径 / 旁白 / 对白
展示战斗占位 encounter_id
展示选择按钮
展示变量变化
展示结局
```

### 2.4 独立测试场景

```text
scenes/NarrativeDemo.tscn
```

用途：

```text
单独打开该场景即可跑压缩叙事 demo。
暂不替换 MainVisual.tscn。
暂不接入现有战斗控制器。
```

---

## 3. 本阶段刻意不做

```text
不改 battle_controller 系列文件；
不改 MainVisual.tscn；
不重构 Web shell；
不接入真实战斗胜负；
不阻塞现有 Web 构建；
不把剧情图强塞进 actor runtime；
不新增复杂地图生成算法。
```

---

## 4. 本地验证方式

### 4.1 Godot 编辑器验证

```text
打开 scenes/NarrativeDemo.tscn
运行当前场景
```

预期：

```text
可以从“十年前 / 海退得很远”一路点击到序章结束；
进入“军令：巡海”；
点击选择后变量变化；
经过推荐路径进入 Boss；
Boss 后进入军门压案；
满足条件时出现上报 / 私查 / 借势等选择；
点击后进入结局。
```

### 4.2 Web 验证建议

当前没有替换主场景。若需要 Web 验证该叙事场景，可临时把 `project.godot` 的 main scene 或导出入口切到：

```text
res://scenes/NarrativeDemo.tscn
```

验证后再切回：

```text
res://scenes/MainVisual.tscn
```

---

## 5. 下一步实装建议

### Step 1：先修编译问题

本地运行 `NarrativeDemo.tscn`，如有 GDScript 类型错误，优先修到可运行。

### Step 2：加真实地图 UI

从当前线性推荐路径升级为一张最小肉鸽地图：

```text
节点圆点
六类节点图标
当前节点高亮
已走节点变暗
```

### Step 3：接战斗结果

现在 battle / elite / boss 节点只是战斗占位。后续可改为：

```text
进入战斗节点
调用现有 battle scene
战斗胜利后回到 NarrativeState
显示战后选择
```

### Step 4：接美术背景

按 `docs/MVP_SINGLE_RUN_ART_COMPLETION_PLAN.md` 的 P0 资产接入：

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

### Step 5：再接角色立绘

优先：

```text
protagonist_young.png
protagonist_child.png
mentor_veteran.png
wakou_leader.png
military_superior.png
```

---

## 6. 当前判断

叙事已经从“文档脚本”推进到“可加载数据 + 可运行状态机 + 独立场景 Demo”的阶段。

下一刀不要扩写剧情，应优先本地跑通：

```text
NarrativeDemo.tscn
→ 无 GDScript 编译错误
→ 序章完整播放
→ 节点选择推进
→ 三变量变化
→ 军门压案
→ 结局出现
```
