# Web 重构进度（持续更新）

## 当前阶段：Milestone D（性能收口后段）

---

## 已完成（核心）

### Web 基线
- [x] compatibility renderer 切换
- [x] Web export preset（单线程）
- [x] Web shell + 本地预览链路

### Visual 架构
- [x] BattleStageHelper（几何缓存 / grid slot 状态构造）
- [x] BattleHudHelper（文本缓存 / intent 文案缓存 / effect preview 文案格式化 / effect preview context 推导）
- [x] BattleSkinHelper（texture / atlas / style cache）
- [x] cached visual controller（wrapper）
- [x] MainVisual 已接入 cached controller

### 稳定性
- [x] 清理所有 Variant 推断 warning（可稳定编译）

---

## 已完成（性能关键路径）

### Stage 渲染
- [x] grid 几何缓存
- [x] grid 差量更新（仅更新变化 slot）
- [x] grid slot 状态构造下沉到 BattleStageHelper

### Overlay
- [x] range overlay 对象池（Polygon2D / Line2D 复用）

### HUD
- [x] intent 文案下沉到 BattleHudHelper
- [x] intent 文案缓存化
- [x] effect preview 文案下沉到 BattleHudHelper
- [x] effect preview 文案缓存化
- [x] effect preview context 推导下沉到 BattleHudHelper

---

## 当前进行中

### Controller
- [x] grid 状态判断从 cached controller 下沉
- [x] effect preview 文案从 cached controller 下沉
- [x] effect preview context 推导从 cached controller 下沉
- [ ] cached visual controller 继续瘦身，仅保留原始输入采集、diff 和 apply

---

## 下一阶段（高收益优化）

### Controller
- [ ] 继续拆薄 cached visual controller
- [ ] 将 range overlay 颜色/绘制配置下沉
- [ ] cached visual controller 只保留绑定与 diff 应用

---

## 最终目标（Milestone D 完成）

- Web 60fps 稳定运行
- 无 GC 峰值
- 无重复节点创建
- UI 构造完全缓存化

---

## 当前结论

👉 Stage diff、overlay pool、intent 文案下沉、grid 状态构造下沉、effect preview 文案与 context 下沉已落地。下一刀聚焦 cached visual controller 最后瘦身：range overlay 配置下沉与绑定层收口。
