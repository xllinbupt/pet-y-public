# Pixel Style Preset

Use this preset when the user asks for a pixel-style desktop pet.

## Visual Rules

- Small desktop companion scale.
- Clear readable silhouette.
- Limited color palette.
- Transparent background.
- Consistent body shape across states.
- Consistent apparent body size across states; identical frame size alone is not enough.
- Stable visual scale and anchor point across frames, especially for idle/rest/sleep.
- Sprite sheet frames arranged horizontally.
- Every frame in a state uses the same frame width and height.
- Avoid complex props unless the state explicitly needs one.

## Base Prompt

Pixel art desktop pet, transparent background, clean silhouette, limited color palette, cute but readable at small size, consistent character design, no scene background, no text.

## Animation Prompt Pattern

Create a horizontal sprite sheet for the same character.

Requirements:

- Transparent background.
- Same character identity in every frame.
- Same frame size in every frame.
- Same apparent body scale across idle, move, rest, sleep, and signature actions, even when the pose changes.
- Locked camera, no per-frame zoom, no per-frame re-centering.
- For idle/rest/sleep, keep the feet/body baseline fixed for grounded pets, or the center fixed for floating pets.
- No camera movement.
- No text.
- No extra background objects.
- Leave enough padding so ears/tail/props do not get cropped.
