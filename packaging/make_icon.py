"""Renders windows/runner/resources/app_icon.ico: a curly handlebar moustache on a warm tile.

Uses the same construction as lib/moustache_painter.dart (bezier half shape, mirrored,
plus tapered spiral curls), drawn large and downsampled for smooth edges.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

S = 1024  # working resolution


def bezier(p0, p1, p2, p3, n=60):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((
            u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
            u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
        ))
    return pts


def render():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # Tile: warm cream rounded square with a soft shadow.
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((70, 90, S - 70, S - 50), 210, fill=(0, 0, 0, 110))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))
    tile = ImageDraw.Draw(img)
    tile.rounded_rectangle((64, 64, S - 64, S - 64), 200, fill=(245, 222, 186, 255))
    tile.rounded_rectangle((64, 64, S - 64, S - 64), 200, outline=(150, 92, 52, 255), width=18)

    # Moustache, in the painter's 200 x 100 design space mapped onto the tile.
    scale, ox, oy = 4.4, S / 2 - 100 * 4.4, S / 2 - 40 * 4.4

    def m(x, y):
        return (ox + x * scale, oy + y * scale)

    top, bottom, width, tip_y, droop, lift, curl = 27, 62, 66, 38, 5, 6, 14
    tip_x = 100 + width
    mid = (top + bottom) / 2
    upper = bezier((100, top + 3), (100 + width * 0.3, top - lift),
                   (100 + width * 0.7, mid - 4 + droop * 0.4), (tip_x, tip_y))
    lower = bezier((tip_x, tip_y), (100 + width * 0.7, tip_y + (bottom - top) * 0.5 + droop),
                   (100 + width * 0.3, bottom + 3), (100, bottom))
    right = upper + lower[1:]
    left = [(200 - x, y) for x, y in reversed(right)]
    colour = (28, 22, 20, 255)
    d = ImageDraw.Draw(img)
    d.polygon([m(x, y) for x, y in right + left], fill=colour)

    # Tapered spiral curls at both tips.
    thickness = (bottom - top) * 0.24
    for side in (1, -1):
        cx, cy = 100 + side * width, tip_y - curl
        for i in range(161):
            t = i / 160
            a = math.pi / 2 - t * 0.85 * 2 * math.pi
            r = curl * (1 - t * 0.7)
            x, y = cx + math.cos(a) * r * side, cy + math.sin(a) * r
            rr = max(0.9, thickness * (1 - t)) * scale
            px, py = m(x, y)
            d.ellipse((px - rr, py - rr, px + rr, py + rr), fill=colour)

    return img


def main():
    out = Path(__file__).resolve().parent.parent / "windows/runner/resources/app_icon.ico"
    big = render()
    sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
    big.resize((256, 256), Image.LANCZOS).save(out, sizes=[(s, s) for s in sizes])
    big.resize((512, 512), Image.LANCZOS).save(Path(__file__).resolve().parent / "icon.png")
    print("wrote", out)


if __name__ == "__main__":
    main()
