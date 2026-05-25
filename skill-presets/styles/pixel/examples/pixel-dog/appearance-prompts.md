# Pixel Dog Appearance Prompts

## Base Character

Pixel art desktop pet dog, 64x64 frame, transparent background, warm yellow body, dark floppy ears, tiny round paws, readable silhouette, limited color palette, cute but not overly detailed, consistent design across animation states, no text, no background.

## Idle

Horizontal sprite sheet, 4 frames, same pixel dog, standing idle, tail gently wagging, occasional blink, transparent background, 64x64 per frame, locked camera, fixed paw baseline, same body size in every frame, no whole-body zoom or re-centering.

## Run

Horizontal sprite sheet, 6 frames, same pixel dog, small running loop, ears and tail bouncing, transparent background, 64x64 per frame, same apparent body size as the approved idle dog.

## Sit

Horizontal sprite sheet, 3 frames, same pixel dog sitting and looking at the user, tail subtly moving, transparent background, 64x64 per frame, locked camera, fixed body baseline, same body size in every frame.

## Sleep

Horizontal sprite sheet, 3 frames, same pixel dog lying down asleep, gentle breathing detail, transparent background, 64x64 per frame, locked camera, fixed body baseline, same body size in every frame, no whole-body resize.

## Carry Ball

Horizontal sprite sheet, 6 frames, same pixel dog trotting while holding a small red ball in its mouth, transparent background, 64x64 per frame, same apparent body size as the approved idle dog.

## Fetch Ball Sequence

Use the run sprite sheet for the outgoing path and the carry-ball sprite sheet for the return path. The Runtime should throw a ball prop to a far screen position, scale the dog down as it runs away, remove the prop when picked up, then scale the dog back to normal size while it carries the ball home.
