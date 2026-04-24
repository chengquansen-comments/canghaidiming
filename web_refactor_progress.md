# Web 重构进度（持续更新）

## 当前阶段：Milestone D（性能收口尾段）

---

## 已完成（核心）

### Web 基线
- [x] compatibility renderer 切换
- [x] Web export preset（单线程）
- [x] Web shell + 本地预览链路

### Visual 架构
- [x] BattleStageHelper（几何缓存 / grid slot 状态构造 / range overlay 配置）
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
- [x] range overlay 颜色 / 线宽 / 层级配置下沉到 BattleStageHelper

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
- [x] range overlay 配置从 cached controller 下沉
- [ ] cached visual controller 最终收口：仅保留原始输入采集、对象池复用、diff 和 apply

---

## 下一阶段（收尾验证）

### 本地验证
- [ ] Godot Editor 编译无 warning-as-error
- [ ] Web export 成功
- [ ] 浏览器运行无 Console error
- [ ] 战斗主流程可点击、可出牌、可预览

### Controller 收尾
- [ ] 检查 cached visual controller 是否仍有可下沉的纯配置 / 纯文案逻辑
- [ ] 保留绑定层职责边界：input collection / diff / pool / apply

---

## 最终目标（Milestone D 完成）

- Web 60fps 稳定运行
- 无 GC 峰值
- 无重复节点创建
- UI 构造完全缓存化

---

## 当前结论

👉 Stage diff、overlay pool、overlay 配置下沉、intent 文案下沉、grid 状态构造下沉、effect preview 文案与 context 下沉已落地。下一步进入收尾验证：先跑 Godot 编译与 Web export，再按报错清残余类型/签名问题。
