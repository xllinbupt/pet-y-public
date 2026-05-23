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
Use the Pet Y Skill to create my own desktop pet.
```

Codex should first install and prepare the Pet Y project. This may take a little time.

For normal users, Codex should download the prebuilt Pet Y Runtime. It should not ask you to fix Xcode, Swift, or macOS SDK versions.

Then Codex should interview you one question at a time before generating your pet. It should ask about:

- pet name
- visual style
- form and appearance
- personality
- actions and behaviors
- how it should emotionally accompany you
- how it should behave when visiting friends

The invited friend should create their own pet. They should not simply run the inviter's sample dog.

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

Install the native Runtime, then use the generated life pack:

```bash
./scripts/install-runtime.sh
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
