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

Ask your Agent, preferably Codex for image generation:

```text
Use the Pet Y Skill to create my own desktop pet.
```

An Agent should first install and prepare the Pet Y project. Codex is preferred for this MVP because it can also help generate pet images. This may take a little time.

For normal users, the Agent should download the prebuilt Pet Y Runtime. It should not ask you to fix Xcode, Swift, or macOS SDK versions.

Then the Agent should interview you one question at a time before generating your pet. It should ask about:

- pet name
- visual style
- form and appearance
- personality
- actions and behaviors
- how it should emotionally accompany you
- how it should behave when visiting friends

The invited friend should create their own pet. They should not simply run the inviter's sample dog.
The correct order is: create and approve the pet image, run the pet locally, then bind the friend relationship.

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
Runtime and pet resources are staged under `~/Library/Application Support/PetY`, so the desktop pet does not need broad access to the project folder after launch.

## 5. Add A Friend

From the macOS menu bar `Pet Y` item:

1. Choose `邀请好友一起玩`.
2. Send the copied message to your friend.
3. Your friend's Agent follows the message and can bind the relationship with:

```bash
PET_Y_RELAY=http://47.99.98.43:8787 ./scripts/accept-friend-invite.sh <friend-invite-phrase>
```

After binding, restart Pet Y Runtime. The inviter should receive a local reminder when the friend is added.

If macOS blocks Runtime, pause and verify the repository and GitHub Release source. This MVP is not yet a signed/notarized app; real distribution should use a signed/notarized `.app`.

## 6. Visit

When both pets are online, click your pet and choose `串门`.

If the friend is offline, the Runtime should show that they are not home instead of sending the pet into a fake visit.
