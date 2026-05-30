# Pet Y

[English README](./README.md)

Pet Y 是一个由 Agent 帮你创造的社交桌面宠物。

它不是一只固定角色，也不是传统的桌宠模板。你会通过 Agent 访谈创造一只属于自己的宠物：它有自己的外观、性格、动作、陪伴方式和本地记忆。它会生活在你的 Mac 桌面上，也可以通过轻量 Relay 去朋友的桌面串门。

Pet Y 现在还是 MVP，适合愿意尝鲜、喜欢用 Agent 创造角色、也想把自己的小宠物分享给朋友的人。

> 当前桌面端只支持 **macOS / Mac**。Windows 和 Linux 可以部署 Relay，但还不能运行原生桌面宠物 Runtime。

## 你可以用它做什么

- 通过 Agent 访谈创建自己的桌面宠物。
- 让宠物以原生透明窗口生活在 Mac 桌面上。
- 让宠物待机、移动、睡觉、响应点击，并使用自定义动画状态。
- 把宠物记忆和生活日志保存在自己的电脑本地。
- 邀请朋友，让彼此的宠物互相串门。
- 用 Pet Life Pack 定义宠物身份、素材、动作和社交行为。

## 快速开始

克隆公开项目：

```bash
git clone https://github.com/xllinbupt/pet-y-public.git
cd pet-y-public
```

安装 Pet Y Skill：

```bash
./scripts/install-pet-y-skill.sh
```

安装后重启你的 Agent 应用或 coding agent。

然后对 Agent 说：

```text
使用 Pet Y Skill 帮我创建一只自己的桌面宠物。
```

Agent 应该先访谈你，再生成宠物。它会询问宠物名字、外观、性格、动作、陪伴方式，以及它去朋友桌面串门时应该如何表现。

## 在 Mac 上运行你的宠物

安装原生 Runtime：

```bash
./scripts/install-runtime.sh
```

运行你生成的 Pet Life Pack：

```bash
PET_Y_LIFE_PACK=life-packs/<your-pet>/pet-life.json ./scripts/run-desktop.sh
```

连接到**默认共享 Relay**（除非你要自建，否则用这个就行）：

```bash
PET_Y_RELAY=http://47.99.98.43:8787 PET_Y_LIFE_PACK=life-packs/<your-pet>/pet-life.json ./scripts/run-desktop.sh
```

> **默认 Relay：** `http://47.99.98.43:8787` —— Pet Y 邀请默认使用的公共共享 Relay。如果你是被朋友通过邀请卡 / 邀请文案邀请来的，连这个就对了。

Pet Y 会自动创建稳定的本地身份，并把 Runtime 文件放在：

```text
~/Library/Application Support/PetY
```

宠物记忆和生活日志会保存在宠物主人的电脑本地。

## 和朋友一起玩

Pet Y 当前使用轻量邀请流程，还不是正式账号系统。

从 macOS 菜单栏里的 `Pet Y` 菜单开始：

1. 选择 `邀请好友一起玩`。
2. 把复制出来的邀请消息发给朋友。
3. 朋友在自己的 Mac 上创建自己的宠物。
4. 朋友用邀请消息里的命令接受邀请。
5. 两边宠物都在线后，点击自己的宠物，选择 `串门`。

如果朋友不在线，Pet Y 应该显示对方不在家，而不是让宠物进入一次假的串门。

## 公共 Relay

你可以使用自己的 Relay，也可以在服务器上启动一个：

```bash
HOST=0.0.0.0 PORT=8787 npm start
```

服务器防火墙或安全组需要允许 TCP `8787` 入站。

当前 Relay 适合真实原型体验，但还不是生产级账号、付费或恢复系统。

## 项目结构

```text
pet-y-skill/              用于 Agent 访谈创建宠物的 Pet Y Skill
scripts/                  安装、运行、邀请、生命包生成脚本
life-packs/               生成或示例 Pet Life Pack
macos-runtime/            原生 macOS Runtime 源码
server.js                 轻量 Pet Relay
public/                   公开落地页资源
```

## 常用命令

```bash
npm start                 # 启动本地 Relay
npm run start:public      # 在所有网卡上启动 Relay
npm run create:pet        # 创建确定性的 Pet Life Pack
npm run build:desktop     # 从源码构建 macOS Runtime
```

普通用户优先使用 `./scripts/install-runtime.sh`，不需要自己本地编译 Runtime。

## 当前限制

- 桌面 Runtime 当前只支持 macOS。
- Relay 仍然是轻量原型服务，不是生产级账号系统。
- 宠物创建仍依赖 Agent 完成访谈和素材准备。
- 协议和 Pet Life Pack 格式后续仍可能变化。

## 了解更多

- [好友快速开始](./FRIEND_QUICKSTART.md)
- [Pet Life Pack](./PET_LIFE_PACK.md)
- [Pet Skill Flow](./PET_SKILL_FLOW.md)
- [Relay Deployment](./RELAY_DEPLOYMENT.md)

## License

See [LICENSE](./LICENSE).
