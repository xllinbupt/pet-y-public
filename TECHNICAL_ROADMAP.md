# Technical Roadmap

## 1. 技术目标

第一阶段的技术目标是做出一个可演示的真实串门闭环：

> 本地生成宠物，本地运行宠物，通过 Relay 把宠物投影到好友桌面，好友互动后事件回传给主人本地，并生成生活日志。

这个阶段不追求完整产品化，而是验证架构是否成立。

## 2. 总体架构

MVP 由四个部分组成：

```text
Pet Skill
  |
  | 生成本地宠物项目、配置、素材和说明
  v
Pet Runtime <---- WebSocket / HTTP ----> Pet Relay <---- WebSocket / HTTP ----> Pet Runtime
  |
  | 本地保存完整宠物状态
  v
Pet Memory
```

### 2.1 Pet Skill

Pet Skill 是 Agent 使用的生成层。

它负责：

- 访谈用户
- 生成宠物设定
- 生成或引用宠物素材
- 生成本地 Runtime 配置
- 生成初始 `PetProfile`
- 告诉用户如何运行和继续定制

Pet Skill 不负责实时运行宠物，也不负责社交通信。

### 2.2 Pet Runtime

Pet Runtime 是本地桌面应用。

它负责：

- 渲染本地宠物
- 渲染来访宠物投影
- 处理点击、拖拽、投喂等互动
- 维护本地完整宠物状态
- 维护生活日志
- 发布 `PetProfile`
- 连接 Relay
- 发起和接收 `VisitSession`
- 上传和接收 `InteractionEvent`
- 将回传事件转成 `MemoryReceipt`

Runtime 是宠物真正存在的地方。

### 2.3 Pet Relay

Pet Relay 是轻量服务。

它负责：

- 用户身份
- 设备连接
- 在线状态
- 好友关系
- 自动来访权限
- `PetProfile` 快照
- `VisitSession`
- `InteractionEvent` 路由

Relay 不运行宠物，不执行宠物行为，不保存完整记忆。

### 2.4 Pet Protocol

Pet Protocol 是 Runtime 和 Relay 之间共享的 JSON 约定。

第一版优先稳定：

- `PetProfile`
- `HostRules`
- `VisitSession`
- `PetProjection`
- `InteractionEvent`
- `MemoryReceipt`

## 3. 技术选型候选

### 3.1 Runtime 方案 A：Electron

优点：

- 透明窗口、置顶窗口、拖拽交互成熟。
- Web 技术开发效率高。
- 动画、Canvas、CSS、WebGL 生态丰富。
- 和 Node.js、本地文件、WebSocket 集成方便。
- 跨平台潜力强。

缺点：

- 资源占用较高。
- 桌面原生质感需要额外打磨。
- 打包体积较大。

适合 MVP 的原因：

Electron 最快验证透明桌面宠物、来访投影和 WebSocket 串门闭环。第一版更需要验证产品机制，而不是极致性能。

### 3.2 Runtime 方案 B：Tauri

优点：

- 体积小，资源占用低。
- 前端仍可用 Web 技术。
- 安全模型比 Electron 更克制。
- 适合未来产品化。

缺点：

- 桌面透明窗口和跨平台细节可能需要更多调试。
- Rust 侧开发门槛更高。
- MVP 迭代速度可能慢一些。

适合后续版本的原因：

如果 MVP 成立，Tauri 适合作为更轻量的产品化 Runtime 候选。

### 3.3 Runtime 方案 C：macOS Swift 原生

优点：

- macOS 桌面体验最好。
- 透明窗口、置顶、动画、系统集成更原生。
- 性能和资源占用优秀。

缺点：

- 初期只适合 macOS。
- Agent 生成和改造项目的门槛更高。
- Web 技术和跨平台生态复用少。

适合特定路线的原因：

如果第一批用户只考虑 macOS，Swift 原生可以做出最舒服的桌面体验。但它不一定最适合“Agent 动态生成项目”的开放目标。

### 3.4 Relay 方案 A：Node.js

优点：

- WebSocket 和 HTTP 开发简单。
- JSON 协议天然匹配。
- 和 Electron 技术栈统一。
- MVP 开发速度快。

缺点：

- 后续高并发和强一致性需要更多工程治理。

适合 MVP 的原因：

Relay 第一版功能很轻，Node.js 足够，并且方便快速迭代协议。

### 3.5 Relay 方案 B：Go

优点：

- 网络服务稳定、高效。
- 部署简单。
- 并发模型适合长连接。

缺点：

- 前期开发速度可能不如 Node.js。
- 和 Agent 生成脚手架的协同稍弱。

适合后续版本的原因：

如果 Relay 需要更稳定的公共服务，Go 是很好的产品化选择。

## 4. MVP 推荐路线

原始方案推荐：

- Runtime：Electron
- Relay：Node.js
- Protocol：JSON + WebSocket + 少量 HTTP API
- Skill：Markdown 指令 + 模板文件 + 生成脚手架
- 本地存储：JSON 文件或 SQLite
- 素材：本地静态资源 + manifest

理由：

- 更快验证真实串门闭环。
- Agent 更容易生成和修改 Web/Electron 项目。
- 前端动画和透明窗口开发成本低。
- Node Relay 可以快速实现在线状态、好友和事件路由。
- JSON 协议方便阅读、调试和文档化。

当前 MVP 实现调整：

- Runtime：macOS Swift/AppKit 原生桌面 Runtime
- Relay：Node.js
- Protocol：JSON + HTTP 轮询事件
- 本地显示：透明置顶宠物窗口 + 原生控制面板
- 动画：Pet Life Pack 中的 sprite sheet PNG + Runtime 叠加位置移动、缩放和气泡
- 本地存储：主人本机 `~/Library/Application Support/PetY/<user-id>/pet-state.json`

调整原因：

- MVP 必须证明宠物真实运行在桌面端，而不是浏览器标签页。
- Swift/AppKit 可以在没有 Electron 依赖的情况下直接创建桌面透明窗口。
- 浏览器 Runtime 仅保留为协议 playground，不作为主 Runtime。

## 5. 数据存储建议

### 5.1 Runtime 本地存储

第一版可以先使用本地目录：

```text
pet-data/
  pet.json
  memories.jsonl
  life-log.jsonl
  relationships.json
  assets/
  profiles/
```

如果事件和日志量变大，再迁移到 SQLite。

本地存储内容：

- 完整宠物设定
- 资源文件
- 生活日志
- 记忆
- 关系牵连
- 本地配置
- 好友缓存

### 5.2 Relay 存储

第一版可以用 SQLite 或轻量 Postgres。

Relay 存储内容：

- 用户
- 设备
- 好友关系
- host rules
- pet profile 快照
- pet profile 版本和素材 hash
- visit session
- interaction event 队列

MVP 本地开发阶段可以先用 SQLite，部署公共服务时再迁移到 Postgres。

## 6. 通信方式

### 6.1 HTTP API

适合请求 / 响应类操作：

- 登录或绑定本地身份
- 添加好友
- 注册宠物，也就是发布 `PetProfile`
- 更新 `PetProfile`
- 获取好友列表
- 获取历史 visit session
- 拉取素材 manifest

### 6.2 WebSocket

适合实时事件：

- Runtime 心跳
- 在线状态变化
- 来访请求
- session 状态变化
- 关键互动事件
- 请回宠物
- 串门结束通知

第一版可以用 WebSocket 作为主通道，HTTP 作为辅助。

当前 MVP 为了减少依赖，先使用 HTTP 轮询事件。WebSocket 仍然适合作为后续产品化的实时通道。

## 7. 第一版开发顺序

### Phase 0：协议和文档定稿

目标：

- 确认 MVP 边界。
- 确认协议对象字段。
- 确认串门流程。
- 确认安全边界。

产物：

- `PRODUCT_VISION.md`
- `PET_PROTOCOL_DRAFT.md`
- `MVP_SCOPE.md`
- `TECHNICAL_ROADMAP.md`

### Phase 1：单机 Runtime 原型

目标：

- 桌面透明窗口。
- 本地宠物显示。
- 基础动画。
- 点击互动。
- 拖拽互动。
- 本地生活日志。

验收：

- 用户能看到宠物在桌面上活动。
- 用户能拖拽和点击宠物。
- 本地能记录互动日志。

### Phase 2：Relay 原型

目标：

- 用户身份。
- Runtime 连接。
- 在线状态。
- 好友关系。
- 发布 `PetProfile`。
- 创建 `VisitSession`。
- WebSocket 事件路由。

验收：

- 两个 Runtime 能同时连接 Relay。
- Relay 能知道双方在线。
- A 能向 B 发起来访 session。

### Phase 3：真实串门闭环

目标：

- A 主动派宠物去 B。
- B Runtime 创建来访投影。
- B 可以点击、拖拽、投喂。
- B 上传互动事件。
- A 收到事件。
- A 生成生活日志。

验收：

- 完成一次端到端串门演示。

### Phase 4：Pet Skill 最小化

目标：

- 将单机 Runtime 原型和协议接入整理成 Agent 可用的生成流程。
- 提供访谈框架。
- 提供风格预设。
- 生成宠物配置和 profile。
- 指导用户运行本地 Runtime。

验收：

- 用户可以通过 Agent 生成一只新的宠物并运行。

当前进度：

- Phase 1 到 Phase 3 的核心演示已经有原型。
- Phase 4 已经有 `Pet Life Pack`、`Pet Skill Flow`、像素风预设和像素狗案例雏形。
- 下一步重点不是继续给 Momo 手写功能，而是把“访谈 -> 生命包 -> 动作素材 -> Runtime 运行 -> 好案例沉淀回 Skill”的流程固化。

## 8. 风险与开放问题

### 8.1 透明窗口兼容性

不同系统对透明窗口、置顶窗口、点击穿透、拖拽的支持不同。

MVP 可以先只验证 macOS，后续再扩展跨平台。

### 8.2 素材一致性

AI 生成的多动作素材可能不一致。

第一版可以先使用少量动作，甚至先用单张图 + 简单动画变换验证机制。

### 8.3 Profile 同步

`PetProfile` 是快照，不是宠物真身。

需要通过版本号和素材 hash 避免宿主 Runtime 使用错误资源。

### 8.4 事件解释

互动事件如何变成宠物记忆，可以先用规则模板实现，再逐步接入 Agent 或模型解释。

### 8.5 安全边界

来访宠物必须是数据投影，不能携带可执行代码。

宿主 Runtime 必须拥有最终控制权。

## 9. 下一步建议

当前不再需要从零开始验证桌面宠物是否能跑起来。下一步建议聚焦三件事：

1. 固化 Pet Skill 访谈流程，让 Agent 能稳定生成新的 `life-packs/<pet-id>/pet-life.json`。
2. 把像素风小狗案例整理成可复用标准，包括外貌提示词、动作提示词、sprite sheet 规格和互动序列。
3. 收敛 Runtime 需要支持的第一批动作执行语义，例如移动、缩放、道具、气泡、状态切换和本地记忆。
