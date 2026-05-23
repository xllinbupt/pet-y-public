# Luma Asset Generation Tasks

Use an image model to generate these sprite sheets. Do not draw the pet with code.

First generate or choose a character reference that establishes the pet's look. After the user approves the reference, generate each action sprite sheet with the same character identity.

General constraints:

- Pixel art desktop pet.
- Transparent background, or flat chroma-key background for local background removal.
- One horizontal sprite sheet per action.
- Every frame must be 64x64 after processing.
- Keep the same pet identity across all actions.
- No text, watermark, shadows, floor, or background props.

Tasks:

## idle

- Output: `assets/idle.png`
- Frames: 4
- Runtime size: 64x64 per frame
- FPS: 6
- Loop: true
- Prompt: 同一只像素风会发光的小星星的 4 帧横向 sprite sheet，待机状态，轻微呼吸感或小幅摆动，透明背景。

## move

- Output: `assets/move.png`
- Frames: 6
- Runtime size: 64x64 per frame
- FPS: 10
- Loop: true
- Prompt: 同一只像素风会发光的小星星的 6 帧横向 sprite sheet，移动动作，角色身份保持一致，透明背景。

## rest

- Output: `assets/rest.png`
- Frames: 3
- Runtime size: 64x64 per frame
- FPS: 4
- Loop: true
- Prompt: 同一只像素风会发光的小星星的 3 帧横向 sprite sheet，安静停留或坐下，看向用户，透明背景。

## sleep

- Output: `assets/sleep.png`
- Frames: 3
- Runtime size: 64x64 per frame
- FPS: 2
- Loop: true
- Prompt: 同一只像素风会发光的小星星的 3 帧横向 sprite sheet，休息或睡觉状态，轻微呼吸感，透明背景。

## signature_glow

- Output: `assets/signature_glow.png`
- Frames: 6
- Runtime size: 64x64 per frame
- FPS: 8
- Loop: false
- Prompt: 同一只像素风会发光的小星星的 6 帧横向 sprite sheet，身体轻轻发光或闪烁，透明背景。

Validation:

- Character still looks like the approved reference.
- Motion reads clearly at desktop pet scale.
- Sheet dimensions match `frames * 64` by `64` after processing.
- Corners are transparent.
- User approves the look before promoting the result as a reusable Skill example.
