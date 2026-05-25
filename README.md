# Pet Y

Pet Y is an agent-generated social desktop pet prototype.

Instead of shipping one fixed pet, Pet Y provides a workflow where an AI agent helps a user create a local desktop pet, run it on macOS, and let it visit friends through a lightweight Relay.

> Current desktop support: **macOS only**. Pet Y's native desktop Runtime is built with Swift/AppKit for Mac. Windows and Linux can host or run the Relay, but they cannot run the desktop pet Runtime yet.

## 中文简介

Pet Y 不是一只固定的桌面宠物，而是一套让 Agent 帮用户“创造宠物生命”的流程。

> 当前桌面端暂时只支持 **macOS / Mac 电脑**。Windows 和 Linux 可以运行 Relay 等服务，但还不能运行桌面宠物 Runtime。

当前原型已经能跑通一个真实社交闭环：

- 用户通过 Pet Y Skill 访谈生成自己的宠物生命包。
- 宠物作为原生 macOS 透明窗口生活在桌面上。
- 宠物可以被摸摸、拖拽、睡觉、丢球互动，并把本地经历写进生活日志。
- 用户可以邀请朋友，让朋友用自己的 Agent 创建另一只宠物。
- 好友之间可以互相串门：宠物离家后会在主人桌面留下牌子，并出现在好友桌面。
- 宿主可以和来访宠物互动、留言或送它回家；这些互动会通过 Relay 回到宠物主人本地，成为宠物的记忆线索。
- 来访宠物的互动菜单会按能力过滤，只展示宿主 Runtime 和宠物名片都支持的动作。

当前项目仍是 MVP：Runtime 只支持 macOS，Relay 仍是轻量内存服务，公开分发还没有签名公证的 `.app` 安装包。

Public repository:

```text
https://github.com/xllinbupt/pet-y-public
```

## What It Does

- Creates Pet Life Packs through an interview-style Skill.
- Runs a native macOS desktop pet in a transparent floating window.
- Supports sprite-sheet animation states such as idle, move, rest, sleep, and signature actions.
- Lets users interact with the pet through quick actions.
- Lets pets visit friends when both users connect to the same Relay.
- Returns lightweight memories from visits back to the pet's owner.
- Copies a friend invitation message from the desktop Runtime.

## Quick Start

Use a Mac for every step that installs or launches the desktop Runtime.

Install the Pet Y Skill locally:

```bash
./scripts/install-pet-y-skill.sh
```

Install the native Runtime:

```bash
./scripts/install-runtime.sh
```

Start a local Relay:

```bash
npm start
```

Run the desktop Runtime:

```bash
./scripts/run-desktop.sh
```

The Runtime creates a stable local identity automatically.
Normal users do not need Xcode or local Swift compilation. Developers changing the Swift Runtime can still run `npm run build:desktop`.

## Create A Pet

Ask an Agent to use the Pet Y Skill. Codex is preferred for the current MVP because it can help generate pet images:

```text
I want to adopt a Pet Y desktop pet. I am using a Mac, and I understand Pet Y currently only supports the macOS desktop Runtime. Please use the Pet Y Skill to create my own desktop pet.
```

The Agent should install and prepare the project, then interview the user before generating a pet. It should ask about name, style, appearance, personality, actions, behaviors, and companionship preferences. Invited friends should create their own pets; they should not simply run the inviter's sample dog.

Or generate a starter Life Pack directly:

```bash
npm run create:pet -- --name Luma --pet-id pet_luma --style pixel --form "会发光的小星星" --signature glow --personality "安静、贴心，会在你分心时轻轻闪一下"
```

Install the native Runtime and run it:

```bash
./scripts/install-runtime.sh
PET_Y_LIFE_PACK=life-packs/luma/pet-life.json ./scripts/run-desktop.sh
```

## Play With Friends

To let pets visit each other, every user must connect to the same Relay:

```bash
PET_Y_RELAY=http://your-relay-host:8787 PET_Y_LIFE_PACK=life-packs/luma/pet-life.json ./scripts/run-desktop.sh
```

From the macOS menu bar `Pet Y` item, choose `邀请好友一起玩`. Pet Y copies a share message containing the public repository, Relay URL, and friend invite phrase.

Your friend should also use a Mac. They give that message to an Agent. Codex is preferred for this MVP because it can help generate pet images. The Agent should create and approve the pet image first, run the pet locally on macOS, then bind the friend relationship with:

```bash
PET_Y_RELAY=http://your-relay-host:8787 ./scripts/accept-friend-invite.sh <friend-invite-phrase>
```

After binding, restart Pet Y Runtime. The inviter receives a local reminder after the friend is added. When both pets are online, click your pet and choose `串门`.

See [Friend Quickstart](./FRIEND_QUICKSTART.md) for the current friend-testing flow.

## Run A Public Relay

On a Linux server:

```bash
HOST=0.0.0.0 PORT=8787 npm start
```

For a systemd service example, see [Relay Deployment](./RELAY_DEPLOYMENT.md).

The current Relay is intentionally lightweight and in-memory. Restarting it clears online sessions, profiles, invites, and friend links. Pet memories remain local on the owner's machine.

## Project Structure

```text
macos-runtime/          Native macOS desktop Runtime
server.js               Lightweight Pet Relay
pet-y-skill/            Codex Skill for creating and editing pets
life-packs/             Sample generated pets
skill-presets/          Reusable style and behavior examples
scripts/                Launch, deployment, and asset helper scripts
public/                 Browser protocol playground
```

## Documents

- [Product Vision](./PRODUCT_VISION.md)
- [Project Progress](./PROJECT_PROGRESS.md)
- [Pet Protocol Draft](./PET_PROTOCOL_DRAFT.md)
- [Pet Life Pack](./PET_LIFE_PACK.md)
- [Pet Skill Flow](./PET_SKILL_FLOW.md)
- [Friend Quickstart](./FRIEND_QUICKSTART.md)

## Current Limits

- macOS Runtime only.
- Runtime is distributed as a prebuilt command-line binary, not a packaged `.app` yet.
- No production account system yet.
- Runtime checks the latest public GitHub Release at startup and from the `Pet Y` menu bar item. If a newer Runtime exists, the menu shows an update item that opens the Release page.
- Relay live sessions are in-memory, but user basics, friend links, and invite phrases are persisted to `data/relay-state.json`.
- Pet art should be generated by an image model or curated by a human; code-drawn sprites are only for disposable engineering tests.
- Generated sprite sheets must keep the pet's apparent body size consistent across action states. Matching `64x64` frame dimensions is not enough if one action makes the pet huge and another makes it tiny.
- Directional animation states can declare `default_facing`: `right`, `left`, or `none`. Missing values default to `right` for backward compatibility. Use `none` for front-facing or directionless states, and keep every frame in a sprite sheet facing the same way.

## Relay Stats

The Relay writes privacy-friendly analytics events to `data/analytics.jsonl` by default. These events count product usage such as Runtime bootstrap, profile registration, invite creation, friend binding, visits, and interaction event types.

The analytics log does not store invite tokens, message text, pet image assets, or local user files. User and pet identifiers are hashed before being written.

Normal users do not need a Relay access code. Friend invite phrases are the user-facing authorization model for adding relationships. Admin stats remain protected by local-only access or `PET_Y_ADMIN_TOKEN`.

Admin stats are available from the Relay host:

```bash
curl http://127.0.0.1:8787/api/admin/stats
```

Public access is denied unless `PET_Y_ADMIN_TOKEN` is configured and provided as `?token=...`.

## License

MIT. See [LICENSE](./LICENSE).
