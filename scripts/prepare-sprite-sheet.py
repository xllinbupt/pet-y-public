#!/usr/bin/env python3
import argparse
from pathlib import Path

from PIL import Image


def remove_green_background(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if g > 150 and r < 90 and b < 90:
                pixels[x, y] = (r, g, b, 0)
    return rgba


def content_bbox(image: Image.Image):
    alpha = image.getchannel("A")
    return alpha.getbbox()


def fit_frames_stable(frames, size: int):
    bboxes = [content_bbox(frame) for frame in frames]
    present = [bbox for bbox in bboxes if bbox]
    if not present:
        return [Image.new("RGBA", (size, size), (0, 0, 0, 0)) for _ in frames]

    max_width = max(bbox[2] - bbox[0] for bbox in present)
    max_height = max(bbox[3] - bbox[1] for bbox in present)
    scale = min((size - 8) / max_width, (size - 8) / max_height)
    baseline = size - 4

    fitted = []
    for frame, bbox in zip(frames, bboxes):
        output = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        if not bbox:
            fitted.append(output)
            continue

        content = frame.crop(bbox)
        next_size = (max(1, round(content.width * scale)), max(1, round(content.height * scale)))
        content = content.resize(next_size, Image.Resampling.LANCZOS)
        x = (size - content.width) // 2
        y = baseline - content.height
        output.alpha_composite(content, (x, y))
        fitted.append(output)
    return fitted


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--frames", type=int, default=4)
    parser.add_argument("--frame-size", type=int, default=64)
    args = parser.parse_args()

    source = remove_green_background(Image.open(args.input))
    source_width, source_height = source.size
    raw_frame_width = source_width / args.frames

    raw_frames = []
    for index in range(args.frames):
        left = round(index * raw_frame_width)
        right = round((index + 1) * raw_frame_width)
        frame = source.crop((left, 0, right, source_height))
        raw_frames.append(frame)

    frames = fit_frames_stable(raw_frames, args.frame_size)

    output = Image.new("RGBA", (args.frame_size * args.frames, args.frame_size), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        output.alpha_composite(frame, (index * args.frame_size, 0))

    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output)


if __name__ == "__main__":
    main()
