---
name: pet-y
description: Create and customize agent-generated desktop pets for Pet Y. Use when a user wants a new desktop pet, a Pet Life Pack, pet animation states, interaction behavior, visit preferences, or wants to modify an existing Pet Y pet through an interview-style flow.
---

# Pet Y Skill

Pet Y is not one fixed pet. It is a workflow for creating a local desktop pet life that can be run by Pet Runtime and visit friends through Pet Relay.

## Core Rule

Generate or edit the pet's `Pet Life Pack`. Do not hard-code one user's pet behavior into Runtime unless the Runtime lacks a reusable execution primitive.

Runtime is the safe local container. Relay is the communication layer. This Skill is the creation process.

## Interview Flow

Ask one focused question at a time. Do not front-load a long questionnaire.

Minimum useful sequence:

1. Style: pixel, hand-drawn sticker, plush/realistic, or custom.
2. Form: any pet life form, including animals, objects, spirits, plants, blobs, tools, abstract companions, or something custom.
3. Personality: emotional value, energy level, attachment style.
4. Actions: idle, move, rest/sleep, and one signature interaction that fits this pet.
5. Social behavior: whether it likes visiting and how noisy it should be as a visitor.
6. Voice: how it speaks in short bubbles and memory logs.

If the user already gives enough information, generate directly and state the assumptions.

## Generate A Pet

For the current MVP, first generate the Life Pack and model-generation tasks:

```bash
npm run create:pet -- --name Luma --pet-id pet_luma --style pixel --form "会发光的小星星" --signature glow --personality "安静、贴心，会在你分心时轻轻闪一下"
```

This creates:

```text
life-packs/<name>/
  pet-life.json
  appearance-prompts.md
  asset-generation-tasks.md
  assets/
```

Do not create pet art by drawing it with code. Use an image model to generate the pet's appearance and action sprite sheets.

Recommended asset workflow:

1. Generate a character reference image for the pet.
2. Show it to the user and get approval on the look.
3. Generate one sprite sheet per action using the approved reference, usually `idle`, `move`, `rest`, `sleep`, and one signature action.
4. Process the generated sheets into Runtime-ready transparent PNG files.
5. Visually review the result on desktop scale before calling the pet finished.

The friend flow order matters:

1. Create and approve the pet's visual identity first.
2. Generate and process the sprite sheets.
3. Run the pet locally and confirm it appears correctly on the desktop.
4. Restart Runtime after replacing or improving pet art assets.
5. Only after the pet works locally, bind the friend relationship.

Then validate:

```bash
node -e "JSON.parse(require('fs').readFileSync('life-packs/<name>/pet-life.json','utf8'))"
```

Install the native Runtime if `~/Library/Application Support/PetY/Runtime/PetYDesktop` is missing:

```bash
./scripts/install-runtime.sh
```

Run the generated pet with:

```bash
PET_Y_LIFE_PACK=life-packs/<name>/pet-life.json ./scripts/run-desktop.sh
```

Runtime creates a local identity automatically on first launch. Do not ask normal users to pick `alice` or `bob`; those are only demo identities.
Do not ask normal users to build Swift locally. Only run `npm run build:desktop` when you changed the Swift Runtime itself.
The launcher stages Runtime and Life Pack files under `~/Library/Application Support/PetY`; avoid running the desktop pet directly from a user's Documents folder.

For a remote friend test, point Runtime at the shared Relay:

```bash
PET_Y_RELAY=http://47.99.98.43:8787 PET_Y_RELAY_SECRET=<relay-access-code> PET_Y_LIFE_PACK=life-packs/<name>/pet-life.json ./scripts/run-desktop.sh
```

After the pet is running locally, bind the friend invite phrase. Prefer the script so an Agent can finish setup without asking the user to manually paste in the Runtime UI:

```bash
PET_Y_RELAY=http://47.99.98.43:8787 PET_Y_RELAY_SECRET=<relay-access-code> ./scripts/accept-friend-invite.sh <friend-invite-phrase>
```

Restart Runtime after binding the friend relationship so the menu and friend status refresh. After both users are online, click the pet and choose `串门`.

If the invite text includes `PET_Y_RELAY_SECRET`, configure it for both running Runtime and accepting the friend invite. Treat it as the Relay access code, separate from the friend invite phrase.

If macOS blocks the Runtime as unsafe, do not teach the user to bypass system security silently. Explain that this MVP is not yet a signed/notarized app, confirm the source repository and Release URL with the user, and prefer a signed/notarized `.app` packaging path for real distribution.

## Life Pack Requirements

Every generated `pet-life.json` should include:

- `profile`: pet identity and Relay-facing profile.
- `profile.interaction_capabilities`: interactions the pet accepts when visiting another desktop.
- `voice`: short bubble lines and memory tone.
- `animation_states`: sprite sheet specs for Runtime.
- `asset_prompts`: prompts for producing or improving sprite sheets.
- `behavior.interactions`: user actions and behavior sequences.
- `memory_rules`: how events become memories.
- `visit_preferences`: default visiting mood and limits.

For a generated pet, include at least:

- `idle`: 4 frames, 64x64 per frame.
- `move`: 6 frames, 64x64 per frame.
- `rest`: 3 frames, 64x64 per frame.
- `sleep`: 3 frames, 64x64 per frame.
- one signature action: usually 4-6 frames, 64x64 per frame.

Prefer generic action names for new pets. Dog-specific states such as `run`, `sit`, and `carry_ball` are supported as legacy/example fallbacks, not as the default shape for every pet.

For a generated pet, declare visitor interaction capabilities conservatively. Default to `petting`, `message`, `return_home`, `pet_to_pet.greeting`, `pet_to_pet.sit_together`, and `pet_to_pet.walk_together`; add capabilities such as `gift.simple` only when the pet's concept and behavior support them.

Baseline interactions must be portable across pet forms. The Runtime can compose them from generic states instead of requiring bespoke art:

- `petting`: use `rest` or a small affection reaction.
- `message`: record a host message for a visiting pet.
- `return_home`: let a host send a visiting pet back.
- `pet_to_pet.greeting`: both pets acknowledge each other with short bubbles.
- `pet_to_pet.sit_together`: the visitor moves near the local pet and both enter `rest`.
- `pet_to_pet.walk_together`: both pets move across the desktop together using `move`.

Use sprite sheet PNG. Plain PNG is not animated by itself; Runtime animates by stepping through frames.

Direction matters for movement states. Generate `move` / `run` / `walk` / `hop` sprite sheets in a consistent canonical direction: prefer right-facing. Set each directional state's `default_facing` to `right` or `left` to match the approved sheet; use `none` for front-facing or directionless states. Runtime flips the sprite from that declared default when the pet moves the other way. Do not mix left-facing and right-facing frames in the same sheet, or the pet will look like it is running backward.

Do not call a pet finished just because the JSON and PNG files exist. A generated pet must pass a visual review: recognizable silhouette, consistent character identity, readable animation, and an appearance the user actually likes.

The correct standard is model-generated or human-curated art. Programmatic drawing can be used only for throwaway engineering tests and must not be promoted as Skill output.

## Interaction Sequences

Describe multi-step actions as behavior sequences, not as a single vague state.

Example fetch-ball sequence for pets where this makes sense:

```text
throw_ball_far -> move_to_target_scale_down -> pick_up_ball -> return_with_ball_scale_up -> rest
```

Runtime executes position, scale, prop windows, bubbles, state changes, and memory writes. The Life Pack describes the intent and required animation states.

## Style Presets

Use existing presets before inventing a new style:

```text
skill-presets/styles/pixel/prompt.md
skill-presets/styles/pixel/examples/pixel-dog/
```

`pixel-dog` is an example, not the default product boundary. Add more examples for non-dog forms as they become good enough.

When a generated pet is good, save its prompts and behavior pattern back under:

```text
skill-presets/styles/<style>/examples/<example-name>/
```

The example should preserve appearance prompts, animation state specs, notes, and the pet-life shape.

## Editing Existing Pets

When the user asks to change a pet:

1. Read its `pet-life.json`.
2. Identify whether the change belongs in `profile`, `voice`, `animation_states`, `asset_prompts`, `behavior`, `memory_rules`, or `visit_preferences`.
3. Edit only the Life Pack unless Runtime lacks a reusable primitive.
4. Validate JSON and rebuild Runtime if Swift changed.

Keep changes narrow. Do not replace the pet's identity unless the user asks.
