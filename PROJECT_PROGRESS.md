# Project Progress

Updated: 2026-05-24

## 1. 当前阶段

Pet Y 现在处于真实好友 MVP 阶段。

目标已经从“证明桌面宠物能跑起来”推进到：

> 让一个真实朋友通过公开仓库和 Pet Y Skill 创建自己的宠物，并和你的宠物互相加好友、互相串门、留下互动记忆。

当前技术形态是：

- macOS Swift/AppKit 原生桌面 Runtime。
- Node.js 轻量 Relay。
- Agent 使用的 Pet Y Skill。
- 本地 Pet Life Pack。
- 公开 GitHub 仓库和预编译 Runtime Release。

## 2. 已完成

### 桌面 Runtime

- 原生 macOS 透明宠物窗口。
- 宠物可以在桌面上移动、被拖拽、睡觉、被摸摸。
- 宠物下方有快捷互动菜单，不依赖右键。
- 本地宠物不再常驻大控制窗口，主要控制入口收敛到宠物和菜单栏。
- Runtime 和 Life Pack 会安装/复制到 `~/Library/Application Support/PetY`，减少对用户文稿目录的持续访问。
- 本地状态、生活日志和记忆保存在主人电脑上。

### 动画与互动

- Runtime 支持 sprite sheet PNG 动画。
- Momo 已有待机、移动、休息/坐下、睡觉、叼球等动作状态。
- 丢球互动实现了“球被丢远、宠物跑远变小、叼球回来变大”的完整序列。
- 摸摸互动增加了通用轻弹/蹭一下反应，即使宠物没有专门素材也会有可见反馈。
- 睡觉触发从自动高频触发收敛为更可控的互动。

### 好友与串门

- Relay 支持用户本地身份、在线状态、好友关系和邀请口令。
- 用户可以复制邀请文案给朋友。
- 朋友可以通过 Agent 创建自己的宠物，再用脚本绑定好友关系。
- 好友绑定成功后，邀请方本地会收到提醒。
- 宠物可以主动被主人派去在线好友桌面。
- 宠物出门后会从主人桌面消失，并留下“我去 XX 那儿”的牌子。
- 出门牌子可以点击，快速喊宠物回家。
- 来访宠物会自动出现在好友桌面。
- 宿主可以摸摸、拖拽、留言、投喂或送回家，具体按钮按能力过滤。
- 本地宠物和来访宠物支持基础互动：打招呼、坐一会儿、一起玩。
- 如果宿主 Runtime 离线，Relay 会自动结束串门，让宠物回家。

### 协议与能力声明

- `PetProfile` 已包含投影所需的轻量信息。
- `interaction_capabilities` 已加入宠物名片，用来声明来访时可接受的互动。
- Runtime 会取“宿主 Runtime 支持能力”和“来访宠物声明能力”的交集，只展示双方都支持的互动。
- 旧宠物没有声明时，默认只支持 `petting`、`message`、`return_home`。
- 留言作为 `VisitEvent` 的 `message` 事件进入 Relay，暂时不要求宠物回复。
- 宠物间互动使用 `pet_to_pet.greeting`、`pet_to_pet.sit_together`、`pet_to_pet.walk_together` 这些通用事件，不绑定某一种动物动作。

### Skill 与公开分享

- `pet-y-skill/SKILL.md` 已说明 Pet Y 不是固定宠物，而是生成宠物生命包的流程。
- Skill 要求 Agent 先访谈用户，再生成宠物形象、动作状态、互动能力和 Life Pack。
- Skill 明确要求不要用代码画正式宠物素材，正式素材应由图像模型生成或人工整理。
- 公开仓库 `xllinbupt/pet-y-public` 已建立。
- 公开 Runtime Release 已发布到 `v0.1.19`。
- 好友 Quickstart 已说明：朋友应创建自己的宠物，不应直接运行邀请人的小狗。

## 3. 当前限制

- Runtime 目前只支持 macOS。
- Runtime 还是预编译命令行二进制，不是签名公证 `.app`。
- macOS 可能会阻止未签名 Runtime，真实分发需要签名、公证和更友好的安装方式。
- Relay 是内存服务，重启会丢失在线状态、邀请、好友关系和活跃串门会话。
- 没有正式账号体系、找回机制、多设备同步或权限后台。
- 宠物不会真正读取宿主文件、屏幕或本地信息，来访宠物只是数据投影。
- 留言只记录和转发，不触发宠物大模型回复。
- 宠物素材质量仍依赖图像生成和人工筛选，自动生成稳定性还不够。

## 4. 下一步建议

优先级最高：

1. 做签名公证 `.app`，降低朋友安装时的安全阻力。
2. 把好友绑定流程再产品化，减少菜单和脚本之间的割裂。
3. 为 Pet Skill 固化“访谈 -> 生图 -> 动作 sprite sheet -> 本地运行 -> 加好友”的标准流程。
4. 增加更明确的公开中文 README 和分享说明，让朋友看到后能理解这是一个 Agent 生成宠物的项目。

随后可以推进：

- Relay 持久化：用户、好友关系、邀请和最近事件。
- 更丰富的人宠互动能力，例如送礼物、拍照、打招呼、宠物和宠物互动。
- 宠物留言后的主人侧可读记录 UI。
- 宠物可选大模型人格，让宠物能在本地或受控服务中回应用户。
- 更通用的跨平台 Runtime 候选，例如 Tauri 或 Electron。

## 5. 当前验证方式

本地验证：

```bash
npm run check
npm run build:desktop
```

运行本地宠物：

```bash
./scripts/install-runtime.sh
PET_Y_LIFE_PACK=life-packs/alice-momo/pet-life.json ./scripts/run-desktop.sh
```

使用共享 Relay：

```bash
PET_Y_RELAY=http://your-relay-host:8787 PET_Y_LIFE_PACK=life-packs/alice-momo/pet-life.json ./scripts/run-desktop.sh
```

公开 Runtime Release：

```text
https://github.com/xllinbupt/pet-y-public/releases
```
