# Dodo Asset Generation Tasks

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
- Prompt: 同一只像素风小狗的 4 帧横向 sprite sheet，站着待机，轻微呼吸或摇尾巴，透明背景。

## run

- Output: `assets/run.png`
- Frames: 6
- Runtime size: 64x64 per frame
- FPS: 10
- Loop: true
- Prompt: 同一只像素风小狗的 6 帧横向 sprite sheet，小跑动作，耳朵和尾巴上下动，透明背景。

## sit

- Output: `assets/sit.png`
- Frames: 3
- Runtime size: 64x64 per frame
- FPS: 4
- Loop: true
- Prompt: 同一只像素风小狗的 3 帧横向 sprite sheet，坐着看向用户，尾巴轻轻动，透明背景。

## sleep

- Output: `assets/sleep.png`
- Frames: 3
- Runtime size: 64x64 per frame
- FPS: 2
- Loop: true
- Prompt: 同一只像素风小狗的 3 帧横向 sprite sheet，趴着睡觉，身体有呼吸起伏，透明背景。

## carry_ball

- Output: `assets/carry_ball.png`
- Frames: 6
- Runtime size: 64x64 per frame
- FPS: 8
- Loop: false
- Prompt: 同一只像素风小狗的 6 帧横向 sprite sheet，叼着红色皮球小跑过来，透明背景。

Validation:

- Character still looks like the approved reference.
- Motion reads clearly at desktop pet scale.
- Sheet dimensions match `frames * 64` by `64` after processing.
- Corners are transparent.
- User approves the look before promoting the result as a reusable Skill example.
