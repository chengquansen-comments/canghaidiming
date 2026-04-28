#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SIZE = (1280, 720)


def _lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def _gradient(top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGBA", SIZE, (*top, 255))
    px = image.load()
    for y in range(SIZE[1]):
        t = y / max(1, SIZE[1] - 1)
        r = _lerp(top[0], bottom[0], t)
        g = _lerp(top[1], bottom[1], t)
        b = _lerp(top[2], bottom[2], t)
        for x in range(SIZE[0]):
            px[x, y] = (r, g, b, 255)
    return image


def _save_pair(name: str, image: Image.Image) -> None:
    for base in (ROOT / "art_reference" / "final", ROOT / "assets" / "pixel_battle" / "backgrounds"):
        base.mkdir(parents=True, exist_ok=True)
        target = base / name
        image.save(target)
        print(target.relative_to(ROOT))


def _overlay_noise(image: Image.Image, alpha: int = 18) -> None:
    noise = Image.effect_noise(SIZE, 42).convert("L")
    ink = Image.new("RGBA", SIZE, (8, 8, 7, alpha))
    image.alpha_composite(Image.composite(ink, Image.new("RGBA", SIZE, (0, 0, 0, 0)), noise))


def _mist(draw: ImageDraw.ImageDraw, y: int, opacity: int) -> None:
    for i in range(8):
        yy = y + i * 18
        draw.ellipse((-120, yy - 48, 940, yy + 74), fill=(168, 180, 174, max(0, opacity - i * 12)))
        draw.ellipse((420, yy - 36, 1430, yy + 58), fill=(130, 146, 144, max(0, opacity - i * 10)))


def prologue_dead_dark_pause() -> Image.Image:
    image = _gradient((11, 13, 14), (35, 25, 20))
    draw = ImageDraw.Draw(image, "RGBA")
    _mist(draw, 380, 42)
    draw.rectangle((0, 510, 1280, 720), fill=(6, 7, 7, 192))
    draw.polygon([(760, 170), (1280, 95), (1280, 720), (690, 720)], fill=(10, 8, 7, 162))
    draw.polygon([(822, 118), (868, 126), (805, 600), (754, 594)], fill=(25, 18, 16, 218))
    draw.line((844, 135, 782, 590), fill=(133, 48, 35, 104), width=4)
    draw.ellipse((554, 340, 674, 410), fill=(95, 32, 26, 62))
    draw.ellipse((518, 372, 710, 448), fill=(0, 0, 0, 108))
    draw.line((235, 384, 945, 396), fill=(214, 187, 120, 34), width=3)
    draw.line((235, 407, 945, 420), fill=(71, 88, 86, 52), width=7)
    draw.rectangle((0, 0, 1280, 720), outline=(0, 0, 0, 72), width=28)
    _overlay_noise(image, 16)
    return image.filter(ImageFilter.UnsharpMask(radius=1.2, percent=115, threshold=4))


def prologue_three_cards() -> Image.Image:
    image = _gradient((20, 21, 19), (45, 34, 24))
    draw = ImageDraw.Draw(image, "RGBA")
    _mist(draw, 410, 34)
    draw.ellipse((780, 120, 1340, 650), fill=(127, 46, 25, 54))
    draw.polygon([(160, 610), (460, 350), (820, 354), (1110, 612)], fill=(8, 8, 7, 142))
    card_specs = [
        (312, 180, 520, 528, -10, (138, 119, 77), "刀"),
        (536, 142, 744, 500, 0, (125, 111, 80), "步"),
        (760, 178, 968, 528, 9, (117, 103, 75), "气"),
    ]
    for left, top, right, bottom, angle, color, mark in card_specs:
        card = Image.new("RGBA", (260, 400), (0, 0, 0, 0))
        cdraw = ImageDraw.Draw(card, "RGBA")
        cdraw.rounded_rectangle((18, 18, 242, 382), radius=18, fill=(31, 27, 22, 232), outline=(*color, 214), width=5)
        cdraw.rounded_rectangle((36, 42, 224, 356), radius=8, outline=(211, 184, 123, 102), width=2)
        cdraw.line((68, 285, 194, 122), fill=(202, 176, 120, 180), width=9)
        if mark == "步":
            cdraw.line((70, 250, 190, 250), fill=(185, 151, 97, 160), width=8)
            cdraw.line((98, 304, 176, 196), fill=(84, 102, 96, 170), width=7)
        elif mark == "气":
            cdraw.arc((64, 148, 200, 284), start=208, end=24, fill=(158, 60, 45, 170), width=9)
            cdraw.line((120, 300, 182, 138), fill=(208, 181, 122, 165), width=7)
        cdraw.ellipse((104, 52, 156, 104), fill=(128, 42, 32, 160))
        cdraw.line((74, 330, 186, 330), fill=(211, 184, 123, 94), width=3)
        card = card.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
        image.alpha_composite(card, ((left + right) // 2 - card.width // 2, (top + bottom) // 2 - card.height // 2))
    draw.rectangle((0, 0, 1280, 720), outline=(0, 0, 0, 64), width=26)
    _overlay_noise(image, 14)
    return image.filter(ImageFilter.UnsharpMask(radius=1.0, percent=120, threshold=3))


def prologue_military_word() -> Image.Image:
    image = _gradient((9, 12, 14), (31, 29, 24))
    draw = ImageDraw.Draw(image, "RGBA")
    _mist(draw, 350, 40)
    draw.ellipse((620, 90, 1300, 620), fill=(95, 28, 22, 54))
    draw.polygon([(0, 560), (1280, 470), (1280, 720), (0, 720)], fill=(5, 7, 7, 178))
    draw.polygon([(258, 238), (356, 232), (420, 540), (188, 548)], fill=(9, 10, 9, 210))
    draw.ellipse((250, 178, 355, 262), fill=(19, 19, 17, 226))
    draw.line((382, 264, 780, 246), fill=(204, 186, 130, 92), width=6)
    draw.line((780, 246, 1110, 190), fill=(25, 22, 18, 210), width=7)
    draw.polygon([(1110, 190), (1168, 160), (1131, 222)], fill=(20, 18, 16, 232))
    draw.line((850, 235, 1050, 202), fill=(126, 40, 32, 150), width=3)
    draw.arc((490, 270, 640, 405), start=204, end=330, fill=(156, 49, 38, 126), width=11)
    draw.line((642, 335, 702, 348), fill=(156, 49, 38, 96), width=8)
    draw.arc((650, 270, 790, 412), start=178, end=300, fill=(156, 49, 38, 70), width=7)
    draw.line((92, 168, 468, 154), fill=(223, 198, 136, 32), width=4)
    draw.line((92, 188, 468, 178), fill=(83, 100, 96, 44), width=6)
    draw.rectangle((0, 0, 1280, 720), outline=(0, 0, 0, 76), width=28)
    _overlay_noise(image, 16)
    return image.filter(ImageFilter.UnsharpMask(radius=1.1, percent=115, threshold=4))


def main() -> int:
    assets = {
        "prologue_dead_dark_pause.png": prologue_dead_dark_pause(),
        "prologue_three_cards.png": prologue_three_cards(),
        "prologue_military_word.png": prologue_military_word(),
    }
    for name, image in assets.items():
        _save_pair(name, image)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
