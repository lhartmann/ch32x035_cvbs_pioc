#! /usr/bin/env python3
import sys
from PIL import Image

im = Image.open("zx81_ascii_font.png")
pixels = im.load()

cnt = {}

def on_pixel(val):
    if val not in cnt:
        cnt[val] = 0
    cnt[val] += 1

def get_byte_for(code,  line):
    x0 = code  % 16 * 9 + 1
    y0 = code // 16 * 9 + 1 + line
    val = 0
    for dx in range(8):
        px = pixels[x0+dx, y0]
        on_pixel(px)
        val = val*2 + (1 if px!=215 else 0)
    return val

# Set pointer: row/2 * 512 + byte*2 + line%1
data = [ 0 ] * 2048
for line in range(8):
    for code in range(256):
        offset = line//2 * 512 + code * 2 + line % 2
        data[offset] = get_byte_for(code%128, line) ^ (0xff if code // 128 else 0)

# PIOC ASM styled font, 16-bit words
# 0x400 + row/2 * 256 + code
out  = "org 0x400\n"
out += "font:\n"

for i in range(1024):
    code  = i %  256
    row_l = i // 256 * 2
    row_h = i // 256 * 2 + 1
    pixels_l = get_byte_for(code%128, row_l)
    pixels_h = get_byte_for(code%128, row_h)

    if code >= 128:
        pixels_l ^= 0xFF
        pixels_h ^= 0xFF

    word = pixels_h * 256 + pixels_l
    out += f'\tDW   {word}\n'

with open("zx81_ascii_font.inc","w") as f:
    f.write(out)

print(cnt)
