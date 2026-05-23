# Pet Y Friend Quickstart

This is the current MVP path for testing Pet Y with a real friend.

## 1. Install The Skill

Public project page:

```text
https://github.com/xllinbupt/pet-y-public
```

From this project:

```bash
./scripts/install-pet-y-skill.sh
```

Restart Codex after installing the Skill.

## 2. Create A Pet

Ask Codex:

```text
Use the Pet Y Skill to create me a pixel-style desktop pet.
```

Codex should interview one question at a time, then create a Pet Life Pack under `life-packs/<name>/`.

## 3. Start The Shared Relay

For the shared Aliyun ECS Relay:

```text
http://47.99.98.43:8787
```

On the server, run from this project:

```bash
HOST=0.0.0.0 PORT=8787 npm start
```

The ECS security group must allow inbound TCP `8787`.

## 4. Run Your Pet

Use the generated life pack:

```bash
PET_Y_RELAY=http://47.99.98.43:8787 PET_Y_LIFE_PACK=life-packs/<name>/pet-life.json ./scripts/run-desktop.sh
```

The Runtime creates a stable local identity automatically.

## 5. Add A Friend

From the macOS menu bar `Pet Y` item:

1. Choose `邀请好友一起玩`.
2. Send the copied message to your friend.
3. Your friend follows the message, then chooses `输入邀请码加好友` and pastes your invite code.

For debugging, `复制我的邀请码` still copies only the raw invite code.

## 6. Visit

When both pets are online, click your pet and choose `串门`.

If the friend is offline, the Runtime should show that they are not home instead of sending the pet into a fake visit.
