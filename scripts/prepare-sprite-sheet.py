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


def fit_frame(frame: Image.Image, size: int) -> Image.Image:
    bbox = content_bbox(frame)
    output = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if not bbox:
        return output

    content = frame.crop(bbox)
    scale = min((size - 8) / content.width, (size - 8) / content.height)
    next_size = (max(1, round(content.width * scale)), max(1, round(content.height * scale)))
    content = content.resize(next_size, Image.Resampling.LANCZOS)
    x = (size - content.width) // 2
    y = (size - content.height) // 2
    output.alpha_composite(content, (x, y))
    return output


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

    frames = []
    for index in range(args.frames):
        left = round(index * raw_frame_width)
        right = round((index + 1) * raw_frame_width)
        frame = source.crop((left, 0, right, source_height))
        frames.append(fit_frame(frame, args.frame_size))

    output = Image.new("RGBA", (args.frame_size * args.frames, args.frame_size), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        output.alpha_composite(frame, (index * args.frame_size, 0))

    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output)


if __name__ == "__main__":
    main()
