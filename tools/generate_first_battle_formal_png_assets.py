#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from random import Random

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
RNG = Random(137)

INK = (9, 10, 9, 255)
DEEP = (15, 17, 17, 255)
MIST = (129, 146, 143, 255)
PAPER = (202, 185, 139, 255)
GOLD = (164, 132, 73, 255)
CINNABAR = (118, 35, 27, 255)
MUD = (78, 67, 49, 255)


def _lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def _gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size, (*top, 255))
    px = image.load()
    for y in range(height):
        t = y / max(1, height - 1)
        r = _lerp(top[0], bottom[0], t)
        g = _lerp(top[1], bottom[1], t)
        b = _lerp(top[2], bottom[2], t)
        for x in range(width):
            px[x, y] = (r, g, b, 255)
    return image


def _noise(size: tuple[int, int], alpha: int = 16, seed: int = 42) -> Image.Image:
    noise = Image.effect_noise(size, seed).convert("L")
    ink = Image.new("RGBA", size, (5, 5, 4, alpha))
    return Image.composite(ink, Image.new("RGBA", size, (0, 0, 0, 0)), noise)


def _save(path: str, image: Image.Image) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target)
    print(target.relative_to(ROOT))


def _poly(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], fill: tuple[int, int, int, int]) -> None:
    draw.polygon([(round(x), round(y)) for x, y in points], fill=fill)


def _reeds(draw: ImageDraw.ImageDraw, width: int, height: int, density: int, side_bias: float = 0.0) -> None:
    for i in range(density):
        if side_bias < 0:
            base_x = RNG.randint(-40, int(width * 0.48))
        elif side_bias > 0:
            base_x = RNG.randint(int(width * 0.48), width + 40)
        else:
            base_x = RNG.randint(-40, width + 40)
        base_y = RNG.randint(int(height * 0.48), height + 30)
        reed_h = RNG.randint(int(height * 0.14), int(height * 0.44))
        lean = RNG.randint(-32, 32)
        color = (17, 19, 17, RNG.randint(105, 190))
        draw.line((base_x, base_y, base_x + lean, base_y - reed_h), fill=color, width=RNG.randint(2, 5))
        if i % 3 == 0:
            tip = base_y - reed_h
            draw.polygon(
                [(base_x + lean, tip), (base_x + lean + 9, tip + 22), (base_x + lean - 7, tip + 16)],
                fill=(69, 55, 37, RNG.randint(72, 132)),
            )


def _distant_boats(draw: ImageDraw.ImageDraw, y: int, count: int) -> None:
    for i in range(count):
        x = 155 + i * 188 + RNG.randint(-42, 46)
        w = RNG.randint(86, 132)
        draw.polygon([(x, y), (x + w, y + 3), (x + w - 18, y + 18), (x + 12, y + 15)], fill=(9, 10, 10, 90))
        draw.line((x + w * 0.45, y - 70, x + w * 0.45, y + 4), fill=(20, 19, 17, 98), width=3)
        draw.polygon([(x + w * 0.47, y - 66), (x + w * 0.78, y - 8), (x + w * 0.47, y - 8)], fill=(34, 34, 31, 76))


def battle_bg_coast_ambush() -> Image.Image:
    size = (1280, 720)
    image = _gradient(size, (30, 39, 40), (19, 17, 14))
    draw = ImageDraw.Draw(image, "RGBA")

    draw.rectangle((0, 0, 1280, 720), fill=(4, 6, 7, 28))
    for y, a in [(165, 38), (210, 32), (264, 25)]:
        draw.ellipse((-120, y - 62, 1120, y + 86), fill=(151, 169, 163, a))
        draw.ellipse((420, y - 38, 1480, y + 82), fill=(96, 119, 120, a))

    draw.polygon([(0, 322), (200, 290), (440, 312), (720, 276), (1020, 306), (1280, 276), (1280, 440), (0, 440)], fill=(29, 35, 33, 150))
    draw.polygon([(0, 354), (190, 340), (438, 352), (662, 330), (900, 354), (1280, 334), (1280, 454), (0, 470)], fill=(82, 94, 89, 55))
    _distant_boats(draw, 318, 5)

    draw.polygon([(0, 434), (1280, 386), (1280, 720), (0, 720)], fill=(42, 38, 29, 235))
    draw.polygon([(0, 488), (1280, 446), (1280, 720), (0, 720)], fill=(22, 22, 18, 170))

    for i in range(34):
        x = RNG.randint(-100, 1280)
        y = RNG.randint(430, 675)
        w = RNG.randint(140, 360)
        draw.arc((x, y, x + w, y + RNG.randint(18, 44)), 184, 352, fill=(160, 166, 145, RNG.randint(18, 52)), width=RNG.randint(2, 5))

    for i in range(12):
        x = 170 + i * 68 + RNG.randint(-16, 16)
        y = 560 + i * 8 + RNG.randint(-18, 18)
        draw.ellipse((x, y, x + 54, y + 20), fill=(56, 47, 34, 120))
        draw.ellipse((x + 11, y + 3, x + 38, y + 13), fill=(102, 84, 57, 70))

    _reeds(draw, 1280, 720, 92, -1)
    _reeds(draw, 1280, 720, 74, 1)

    # Enemy spears and disciplined silhouettes emerge from the reeds.
    for x, y, scale, alpha in [(805, 428, 1.0, 195), (925, 406, 0.88, 160), (1038, 442, 0.72, 128)]:
        draw.line((x - 120 * scale, y - 72 * scale, x + 150 * scale, y - 128 * scale), fill=(12, 12, 10, alpha), width=max(4, round(7 * scale)))
        draw.polygon([(x + 150 * scale, y - 128 * scale), (x + 184 * scale, y - 144 * scale), (x + 160 * scale, y - 106 * scale)], fill=(179, 165, 121, alpha))
        draw.ellipse((x - 22 * scale, y - 112 * scale, x + 20 * scale, y - 70 * scale), fill=(10, 10, 9, alpha))
        draw.polygon([(x - 38 * scale, y - 70 * scale), (x + 34 * scale, y - 68 * scale), (x + 52 * scale, y + 70 * scale), (x - 50 * scale, y + 72 * scale)], fill=(8, 9, 8, alpha))
        draw.line((x - 44 * scale, y + 68 * scale, x - 80 * scale, y + 168 * scale), fill=(6, 7, 6, alpha), width=max(5, round(9 * scale)))
        draw.line((x + 42 * scale, y + 68 * scale, x + 76 * scale, y + 168 * scale), fill=(6, 7, 6, alpha), width=max(5, round(9 * scale)))

    # Official mud clue in a safe foreground pocket.
    for x, y in [(708, 618), (762, 646), (822, 674)]:
        draw.ellipse((x, y, x + 70, y + 24), fill=(93, 75, 44, 112))
        draw.arc((x + 9, y + 4, x + 60, y + 21), 190, 350, fill=(185, 146, 78, 72), width=3)
    draw.line((682, 602, 915, 690), fill=(180, 144, 78, 56), width=4)

    draw.rectangle((0, 0, 1280, 720), outline=(0, 0, 0, 78), width=28)
    image.alpha_composite(_noise(size, 18, 48))
    return image.filter(ImageFilter.UnsharpMask(radius=1.2, percent=112, threshold=5))


def narrative_beach_ambush() -> Image.Image:
    base = battle_bg_coast_ambush()
    image = base.resize((1280, 720), Image.Resampling.LANCZOS)
    draw = ImageDraw.Draw(image, "RGBA")
    draw.rectangle((0, 0, 1280, 720), fill=(0, 0, 0, 16))
    draw.rectangle((0, 430, 1280, 720), fill=(0, 0, 0, 28))
    draw.ellipse((505, 455, 980, 725), fill=(153, 122, 67, 34))
    image.alpha_composite(_noise((1280, 720), 10, 21))
    return image


def official_mud_bootprint() -> Image.Image:
    size = (1024, 1024)
    image = _gradient(size, (38, 35, 29), (20, 20, 17))
    draw = ImageDraw.Draw(image, "RGBA")
    draw.ellipse((-100, 720, 1120, 1120), fill=(9, 10, 9, 138))
    for i in range(5):
        x = 168 + i * 128
        y = 270 + i * 74
        draw.ellipse((x, y, x + 188, y + 70), fill=(91, 73, 42, 160))
        draw.ellipse((x + 20, y + 10, x + 158, y + 58), fill=(128, 96, 52, 62))
        draw.arc((x + 38, y + 18, x + 142, y + 54), 190, 352, fill=(202, 164, 86, 114), width=7)
        draw.line((x + 62, y + 21, x + 76, y + 50), fill=(30, 27, 21, 75), width=4)
        draw.line((x + 100, y + 18, x + 108, y + 48), fill=(30, 27, 21, 72), width=4)
    draw.rounded_rectangle((640, 230, 826, 394), radius=16, fill=(74, 42, 30, 150), outline=(184, 130, 67, 150), width=5)
    draw.ellipse((684, 264, 782, 360), outline=(216, 162, 83, 176), width=7)
    draw.rectangle((712, 292, 754, 335), outline=(216, 162, 83, 138), width=5)
    _reeds(draw, 1024, 1024, 42, 0)
    image.alpha_composite(_noise(size, 18, 15))
    return image.filter(ImageFilter.UnsharpMask(radius=1.0, percent=120, threshold=4))


def beach_body_search() -> Image.Image:
    size = (1024, 1024)
    image = _gradient(size, (42, 39, 33), (18, 18, 15))
    draw = ImageDraw.Draw(image, "RGBA")
    draw.polygon([(0, 690), (1024, 610), (1024, 1024), (0, 1024)], fill=(10, 10, 9, 142))
    draw.ellipse((170, 460, 834, 748), fill=(8, 9, 8, 110))
    draw.polygon([(240, 532), (620, 468), (720, 540), (344, 650)], fill=(32, 29, 24, 230))
    draw.polygon([(575, 488), (742, 410), (785, 468), (690, 548)], fill=(63, 42, 30, 210))
    draw.ellipse((704, 370, 790, 450), fill=(21, 19, 16, 230))
    draw.line((315, 538, 205, 424), fill=(17, 16, 14, 220), width=25)
    draw.line((310, 632, 178, 746), fill=(14, 14, 12, 220), width=26)
    draw.line((625, 538, 824, 606), fill=(17, 16, 14, 220), width=20)
    draw.rounded_rectangle((430, 650, 610, 790), radius=18, fill=(123, 103, 72, 208), outline=(212, 178, 105, 126), width=4)
    draw.line((470, 688, 570, 676), fill=(57, 47, 32, 150), width=7)
    draw.line((466, 726, 552, 722), fill=(57, 47, 32, 130), width=5)
    draw.ellipse((672, 616, 744, 652), fill=(83, 68, 44, 170))
    draw.line((662, 625, 814, 584), fill=(193, 164, 108, 122), width=5)
    for i in range(9):
        x = RNG.randint(120, 880)
        y = RNG.randint(710, 920)
        draw.arc((x, y, x + RNG.randint(90, 180), y + RNG.randint(12, 36)), 185, 354, fill=(155, 157, 133, 32), width=3)
    image.alpha_composite(_noise(size, 18, 33))
    return image.filter(ImageFilter.UnsharpMask(radius=1.0, percent=118, threshold=4))


def wakou_ambusher() -> Image.Image:
    size = (1024, 1024)
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    for x, y, scale, alpha in [(420, 410, 1.28, 230), (650, 470, 0.92, 156), (260, 510, 0.82, 132)]:
        draw.line((x - 210 * scale, y - 72 * scale, x + 236 * scale, y - 156 * scale), fill=(8, 9, 7, alpha), width=round(14 * scale))
        draw.polygon([(x + 236 * scale, y - 156 * scale), (x + 300 * scale, y - 188 * scale), (x + 256 * scale, y - 116 * scale)], fill=(176, 160, 116, alpha))
        draw.ellipse((x - 36 * scale, y - 148 * scale, x + 36 * scale, y - 78 * scale), fill=(6, 7, 6, alpha))
        draw.polygon([(x - 58 * scale, y - 72 * scale), (x + 64 * scale, y - 76 * scale), (x + 86 * scale, y + 142 * scale), (x - 82 * scale, y + 146 * scale)], fill=(6, 7, 6, alpha))
        draw.line((x - 62 * scale, y + 128 * scale, x - 132 * scale, y + 318 * scale), fill=(4, 5, 4, alpha), width=round(18 * scale))
        draw.line((x + 58 * scale, y + 128 * scale, x + 128 * scale, y + 318 * scale), fill=(4, 5, 4, alpha), width=round(18 * scale))
        draw.line((x - 120 * scale, y - 42 * scale, x + 96 * scale, y - 52 * scale), fill=(105, 33, 26, min(150, alpha)), width=round(8 * scale))
    _reeds(draw, 1024, 1024, 74, 0)
    return image.filter(ImageFilter.GaussianBlur(0.15))


def _draw_spearman_frame(frame: Image.Image, x: int, y: int, scale: float, facing: int, palette: str, pose: str) -> None:
    draw = ImageDraw.Draw(frame, "RGBA")
    armor = (38, 39, 34, 255) if palette == "enemy" else (45, 42, 37, 255)
    robe = (75, 25, 21, 255) if palette == "enemy" else (91, 31, 24, 255)
    trim = (147, 119, 68, 255)
    skin = (166, 128, 86, 255)
    sx = scale * facing
    def p(dx: float, dy: float) -> tuple[int, int]:
        return (round(x + dx * sx), round(y + dy * scale))
    def box(dx0: float, dy0: float, dx1: float, dy1: float) -> tuple[int, int, int, int]:
        x0, y0 = p(dx0, dy0)
        x1, y1 = p(dx1, dy1)
        return (min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1))

    spear_y = -48
    spear_tip = 132
    if pose == "thrust":
        spear_y = -68
        spear_tip = 178
    elif pose == "guard":
        spear_y = -92
        spear_tip = 112
    elif pose == "hurt":
        spear_y = -34
        spear_tip = 90
    draw.line((*p(-112, spear_y), *p(spear_tip, spear_y - 18)), fill=(92, 59, 31, 255), width=max(4, round(7 * scale)))
    draw.polygon([p(spear_tip, spear_y - 18), p(spear_tip + 30, spear_y - 32), p(spear_tip + 9, spear_y + 2)], fill=(194, 180, 130, 255))
    draw.line((*p(spear_tip - 18, spear_y - 14), *p(spear_tip + 2, spear_y + 24)), fill=(119, 36, 27, 190), width=max(2, round(4 * scale)))

    draw.ellipse(box(-22, -168, 22, -126), fill=skin)
    draw.polygon([p(-30, -170), p(30, -174), p(18, -140), p(-28, -138)], fill=(12, 12, 11, 255))
    draw.polygon([p(-54, -120), p(54, -120), p(66, 24), p(-66, 24)], fill=armor)
    draw.polygon([p(-74, -98), p(-44, -112), p(-18, 12), p(-58, 34)], fill=robe)
    draw.polygon([p(74, -98), p(42, -112), p(18, 12), p(58, 34)], fill=robe)
    for yy in [-90, -62, -34, -6]:
        draw.line((*p(-46, yy), *p(48, yy)), fill=trim, width=max(2, round(3 * scale)))
    draw.line((*p(-34, 18), *p(-70, 116)), fill=(14, 15, 13, 255), width=max(7, round(11 * scale)))
    draw.line((*p(34, 18), *p(74, 116)), fill=(14, 15, 13, 255), width=max(7, round(11 * scale)))
    draw.ellipse(box(-82, 106, -34, 126), fill=(9, 9, 8, 255))
    draw.ellipse(box(36, 106, 90, 126), fill=(9, 9, 8, 255))
    draw.ellipse((x - round(78 * scale), y + round(112 * scale), x + round(82 * scale), y + round(134 * scale)), fill=(0, 0, 0, 76))


def spearman_sheet(enemy: bool) -> Image.Image:
    frame_w, frame_h = 256, 256
    sheet = Image.new("RGBA", (frame_w * 6, frame_h * 2), (0, 0, 0, 0))
    palette = "enemy" if enemy else "hero"
    poses = ["idle", "guard", "thrust", "thrust", "hurt", "idle", "idle", "guard", "thrust", "hurt", "guard", "idle"]
    for i, pose in enumerate(poses):
        frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
        _draw_spearman_frame(frame, 128, 126, 0.92, -1 if enemy else 1, palette, pose)
        sheet.alpha_composite(frame, ((i % 6) * frame_w, (i // 6) * frame_h))
    return sheet.filter(ImageFilter.UnsharpMask(radius=0.8, percent=120, threshold=3))


def spearman_portrait(enemy: bool) -> Image.Image:
    size = (512, 512)
    image = _gradient(size, (32, 34, 31), (15, 15, 13))
    draw = ImageDraw.Draw(image, "RGBA")
    draw.ellipse((140, 70, 590, 520), fill=(121, 42, 28, 46))
    _draw_spearman_frame(image, 250, 382, 1.35, -1 if enemy else 1, "enemy" if enemy else "hero", "guard")
    draw.rectangle((0, 0, 512, 512), outline=(0, 0, 0, 90), width=18)
    image.alpha_composite(_noise(size, 12, 39))
    return image.filter(ImageFilter.UnsharpMask(radius=1.0, percent=118, threshold=4))


def main() -> int:
    outputs = {
        "assets/pixel_battle/backgrounds/battle_bg_coast_ambush.png": battle_bg_coast_ambush(),
        "assets/pixel_battle/backgrounds/narrative_beach_ambush.png": narrative_beach_ambush(),
        "assets/narrative/props/prop_official_mud_bootprint.png": official_mud_bootprint(),
        "assets/narrative/props/prop_beach_body_search.png": beach_body_search(),
        "assets/narrative/silhouettes/sil_wakou_ambusher.png": wakou_ambusher(),
        "assets/pixel_battle/sheets/enemy_spearman_sheet.png": spearman_sheet(True),
        "assets/pixel_battle/sheets/spearman_sheet.png": spearman_sheet(False),
        "assets/pixel_battle/portraits/spearman_portrait.png": spearman_portrait(False),
        "assets/pixel_battle/portraits/enemy_spearman_story.png": spearman_portrait(True),
    }
    for path, image in outputs.items():
        _save(path, image)
    # Keep formal reference copies for art review without changing runtime paths.
    for name in ["battle_bg_coast_ambush", "narrative_beach_ambush"]:
        source = outputs[f"assets/pixel_battle/backgrounds/{name}.png"]
        _save(f"art_reference/final/pixel_battle/backgrounds/{name}.png", source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
