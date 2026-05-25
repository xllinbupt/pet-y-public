# Pixel Dog Notes

This example captures the first reusable pixel-style dog pattern.

Use it as a reference when users ask for:

- pixel dog
- puppy desktop pet
- energetic pet that brings a ball
- small companion with run / sit / sleep states

Important reusable decisions:

- Use sprite sheet PNG, not animated PNG.
- Keep every state at 64x64 per frame.
- Keep the dog shape and apparent body size consistent across all states; do not let one action fill the frame while another makes the dog tiny.
- Props such as the ball appear only in the relevant state.
- The pet can carry a ball as a returned-gift animation.
- Fetch-ball is a full sequence, not a single pose: throw the ball far away, run to it while scaling down, pick it up, carry it back while scaling up, then sit.

Generated asset note:

- `assets/idle-generated.png` is a normalized 4-frame 256x64 transparent sprite sheet prepared from an AI-generated chroma-key source.
- Use `scripts/prepare-sprite-sheet.py` to convert generated green-background sprite sheets into Runtime-ready transparent PNGs.
