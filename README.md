# Pet Y

[中文说明](./README.zh-CN.md)

Pet Y is an agent-created social desktop pet.

Instead of downloading a fixed character, you ask an Agent to help you create a pet with its own look, personality, behaviors, and local memories. Your pet lives on your Mac desktop, can react to you, and can visit friends through a lightweight Relay.

Pet Y is currently an MVP. It is meant for people who enjoy trying early products, creating characters with Agents, and sharing strange little desktop creatures with friends.

> Current desktop support: **macOS only**. Windows and Linux can host the Relay, but they cannot run the native desktop pet Runtime yet.

## What You Can Do

- Create your own desktop pet through an Agent-guided interview.
- Run the pet as a native transparent macOS desktop companion.
- Let the pet idle, move, sleep, react to clicks, and use custom animated states.
- Keep pet memories and life logs locally on your machine.
- Invite friends and let pets visit each other's desktops.
- Use Pet Life Packs to define each pet's identity, assets, actions, and social behavior.

## Quick Start

Clone the public project:

```bash
git clone https://github.com/xllinbupt/pet-y-public.git
cd pet-y-public
```

Install the Pet Y Skill locally:

```bash
./scripts/install-pet-y-skill.sh
```

Restart your Agent app or coding agent after installing the Skill.

Then ask your Agent:

```text
Use the Pet Y Skill to create my own desktop pet.
```

The Agent should interview you before generating the pet. It should ask about the pet's name, appearance, personality, actions, emotional style, and how it should behave around friends.

## Run Your Pet On Mac

Install the native Runtime:

```bash
./scripts/install-runtime.sh
```

Run a generated Pet Life Pack:

```bash
PET_Y_LIFE_PACK=life-packs/<your-pet>/pet-life.json ./scripts/run-desktop.sh
```

To connect to the **default shared Relay** (use this unless you are self-hosting):

```bash
PET_Y_RELAY=http://47.99.98.43:8787 PET_Y_LIFE_PACK=life-packs/<your-pet>/pet-life.json ./scripts/run-desktop.sh
```

> **Default Relay:** `http://47.99.98.43:8787` — the public shared Relay used by Pet Y invites. If you received an invite card or message from a friend, this is the Relay you should connect to.

Pet Y creates a stable local identity automatically and stages Runtime files under:

```text
~/Library/Application Support/PetY
```

Pet memories and life logs stay on the pet owner's machine.

## Play With Friends

Pet Y uses a lightweight invite flow instead of a production account system.

From the macOS menu bar `Pet Y` item:

1. Choose `邀请好友一起玩`.
2. Send the copied invite message to your friend.
3. Your friend creates their own pet on a Mac.
4. Your friend accepts the invite with the command included in the message.
5. When both pets are online, click your pet and choose `串门`.

If your friend is offline, Pet Y should show that they are not home instead of sending your pet into a fake visit.

## Public Relay

You can use your own Relay, or run one on a server:

```bash
HOST=0.0.0.0 PORT=8787 npm start
```

The server firewall or security group must allow inbound TCP `8787`.

The current Relay is suitable for a live prototype. It is not a production account, payment, or recovery service.

## Project Layout

```text
pet-y-skill/              Pet Y Skill for Agent-guided pet creation
scripts/                  Install, launch, invite, and life-pack helper scripts
life-packs/               Generated or sample Pet Life Packs
macos-runtime/            Native macOS Runtime source
server.js                 Lightweight Pet Relay
public/                   Public landing page assets
```

## Useful Commands

```bash
npm start                 # start the local Relay
npm run start:public      # start the Relay on all interfaces
npm run create:pet        # create a deterministic Pet Life Pack
npm run build:desktop     # build the macOS Runtime from source
```

Normal users should prefer `./scripts/install-runtime.sh` instead of building the Runtime locally.

## Current Limits

- Desktop Runtime currently supports macOS only.
- The Relay is intentionally lightweight and not a production account system.
- Pet creation still depends on an Agent to guide the interview and prepare assets.
- The protocol and Pet Life Pack format may still change.

## Learn More

- [Friend Quickstart](./FRIEND_QUICKSTART.md)
- [Pet Life Pack](./PET_LIFE_PACK.md)
- [Pet Skill Flow](./PET_SKILL_FLOW.md)
- [Relay Deployment](./RELAY_DEPLOYMENT.md)

## License

See [LICENSE](./LICENSE).
