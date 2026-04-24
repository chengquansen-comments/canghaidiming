# Web 重构进度（持续更新）

## 当前阶段：Milestone C → D（性能收口阶段）

---

## 已完成（核心）

### Web 基线
- [x] compatibility renderer 切换
- [x] Web export preset（单线程）
- [x] Web shell + 本地预览链路

### Visual 架构
- [x] BattleStageHelper（几何缓存）
- [x] BattleHudHelper（文本缓存）
- [x] BattleSkinHelper（texture / atlas / style cache）
- [x] cached visual controller（wrapper）
- [x] MainVisual 已接入 cached controller

### 稳定性
- [x] 清理 BattleSkinHelper Variant 推断 warning

---

## 当前阻塞（必须优先清掉）

### 1. HUD / Stage 仍存在 Variant 推断风险
- battle_hud_view.gd
- battle_stage_view.gd

👉 目标：所有 Dictionary / Object 访问必须显式类型

### 2. Visual Controller 仍存在重复装配
- style 构造仍部分存在 controller 内
- grid 每帧全量刷新

---

## 下一阶段（高收益优化）

### Stage 渲染
- [ ] grid 差量更新（只更新变化 slot）

### Overlay
- [ ] range overlay 对象池（禁止 free + new）

### HUD
- [ ] intent 文案完全下沉到 helper

### Controller
- [ ] visual controller 只做绑定，不做构造

---

## 最终目标（Milestone D 完成）

- Web 60fps 稳定运行
- 无 GC 峰值
- 无重复节点创建
- UI 构造完全缓存化

---

## 当前结论

👉 已进入性能收口阶段，但仍需清理类型系统与重复构造
