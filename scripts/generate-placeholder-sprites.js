import fs from "node:fs";
import zlib from "node:zlib";

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let i = 0; i < 8; i += 1) {
      crc = crc & 1 ? (crc >>> 1) ^ 0xedb88320 : crc >>> 1;
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const typeBuffer = Buffer.from(type);
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuffer, data])));
  return Buffer.concat([length, typeBuffer, data, crc]);
}

function drawPixelDog(pixels, width, frame, color) {
  const offsetX = frame * 64;
  const bob = frame % 2;
  const set = (x, y, rgba) => {
    const px = offsetX + x;
    if (px < 0 || px >= width || y < 0 || y >= 64) return;
    const index = (y * width + px) * 4;
    pixels[index] = rgba[0];
    pixels[index + 1] = rgba[1];
    pixels[index + 2] = rgba[2];
    pixels[index + 3] = rgba[3];
  };
  const rect = (x, y, w, h, rgba) => {
    for (let yy = y; yy < y + h; yy += 1) {
      for (let xx = x; xx < x + w; xx += 1) set(xx, yy, rgba);
    }
  };

  const body = color;
  const outline = [32, 33, 36, 255];
  const ear = [82, 62, 52, 255];
  const blush = [238, 123, 108, 255];

  rect(20, 24 - bob, 26, 20, outline);
  rect(22, 26 - bob, 22, 16, body);
  rect(40, 18 - bob, 14, 14, outline);
  rect(42, 20 - bob, 10, 10, body);
  rect(44, 13 - bob, 8, 8, outline);
  rect(45, 14 - bob, 6, 6, ear);
  rect(49, 24 - bob, 2, 2, outline);
  rect(53, 26 - bob, 2, 2, blush);
  rect(24, 42 - bob, 4, 7, outline);
  rect(38, 42 - bob, 4, 7, outline);
  rect(10, 29 - bob + (frame % 3), 11, 5, outline);
}

function makeSpriteSheet(path, color) {
  const frames = 4;
  const width = 64 * frames;
  const height = 64;
  const pixels = Buffer.alloc(width * height * 4);
  for (let frame = 0; frame < frames; frame += 1) {
    drawPixelDog(pixels, width, frame, color);
  }

  const rawRows = [];
  for (let y = 0; y < height; y += 1) {
    rawRows.push(Buffer.from([0]));
    rawRows.push(pixels.subarray(y * width * 4, (y + 1) * width * 4));
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  const png = Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(Buffer.concat(rawRows))),
    chunk("IEND", Buffer.alloc(0))
  ]);
  fs.writeFileSync(path, png);
}

makeSpriteSheet("life-packs/alice-momo/assets/idle.png", [107, 198, 168, 255]);
makeSpriteSheet("life-packs/bob-yuzu/assets/idle.png", [238, 123, 108, 255]);
makeSpriteSheet("skill-presets/styles/pixel/examples/pixel-dog/assets/idle.png", [217, 164, 95, 255]);

console.log("placeholder sprite sheets generated");
