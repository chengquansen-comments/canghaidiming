# Web 重构进度（持续更新）

## 当前阶段：Milestone D（性能收口进行中）

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
- [x] 清理所有 Variant 推断 warning（可稳定编译）

---

## 当前进行中（核心性能优化）

### Stage 渲染
- [x] grid 几何缓存
- [x] grid 差量更新（仅更新变化 slot）

👉 已避免每帧全量 repaint

---

## 下一阶段（高收益优化）

### Overlay
- [ ] range overlay 对象池（当前仍是 clear + new）

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

👉 已进入性能关键优化阶段（Stage diff 已落地）
