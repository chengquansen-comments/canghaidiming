# Web 构建已知问题归档

当前 Web 已知问题基线已并入 [web_refactor_progress.md](web_refactor_progress.md)。

保留结论：

- Headless Chrome `SharedImageManager::ProduceMemory` warning 当前为非阻塞。
- `Chrome --dump-dom` 不稳定观察 Godot Web 异步启动后的 DOM 标记，当前为待确认。
- 当前 Web 阻塞项暂无。

后续新增 Web 阻塞项，直接更新 [web_refactor_progress.md](web_refactor_progress.md)。
