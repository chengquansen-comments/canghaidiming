#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FINAL = ROOT / "art_reference" / "final"
ASSETS = ROOT / "assets" / "pixel_battle"
FINAL_PIXEL_BATTLE = FINAL / "pixel_battle"
PROLOGUE_TARGET = ASSETS / "backgrounds" / "formal" / "prologue"
PROLOGUE_SOURCE = FINAL_PIXEL_BATTLE / "backgrounds" / "formal" / "prologue"
SOURCE_BACKGROUNDS = FINAL_PIXEL_BATTLE / "backgrounds"
SOURCE_SHEETS = FINAL_PIXEL_BATTLE / "sheets"
SOURCE_PORTRAITS = FINAL_PIXEL_BATTLE / "portraits"

BACKGROUND_SIZE = (1280, 720)
SPEARMAN_FRAME_SIZE = (1536, 512)
ENEMY_FRAME_SIZE = (1024, 512)
ENEMY_FOOT_ANCHOR = (430.0, 492.0)
ENEMY_SPEARMAN_FRAME_SIZE = (1536, 512)
ENEMY_SPEARMAN_FOOT_ANCHOR = (768.0, 492.0)
MASTER_FRAME_SIZE = (512, 512)
MASTER_FOOT_ANCHOR = (256.0, 500.0)


def require_pillow():
    try:
        from PIL import Image

        return Image
    except Exception as exc:
        raise SystemExit(
            "[promote-final-art] ERROR: Pillow is required.\n"
            "Run: python3 -m pip install pillow\n"
            f"Original error: {exc}"
        )


Image = require_pillow()


def fail(message: str) -> None:
    print(f"[promote-final-art] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def cover_resize(image, size: tuple[int, int]):
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = max(0, (resized.width - target_w) // 2)
    top = max(0, (resized.height - target_h) // 2)
    return resized.crop((left, top, left + target_w, top + target_h))


def save_png(path: Path, image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"[promote-final-art] wrote {rel(path)} {image.width}x{image.height} {image.mode}")


def _safe_alpha_composite(dest, source, offset: tuple[int, int]) -> None:
    x, y = offset
    left = max(0, x)
    top = max(0, y)
    right = min(dest.width, x + source.width)
    bottom = min(dest.height, y + source.height)
    if right <= left or bottom <= top:
        return
    crop = source.crop((left - x, top - y, right - x, bottom - y))
    dest.alpha_composite(crop, (left, top))


def alpha_bbox(image, threshold: int = 8):
    alpha = image.getchannel("A")
    return alpha.point(lambda value: 255 if value > threshold else 0).getbbox()


def remove_checkerboard_background(image):
    """Conservative cleanup for RGB exports composited on a light checkerboard."""
    image = image.convert("RGBA")
    width, height = image.size
    src = image.load()
    candidate = bytearray(width * height)
    for y in range(height):
        row = y * width
        for x in range(width):
            r, g, b, a = src[x, y]
            spread = max(r, g, b) - min(r, g, b)
            if a > 0 and min(r, g, b) >= 224 and spread <= 18:
                candidate[row + x] = 1

    outside = bytearray(width * height)
    stack: list[int] = []

    def push(index: int) -> None:
        if candidate[index] and not outside[index]:
            outside[index] = 1
            stack.append(index)

    for x in range(width):
        push(x)
        push((height - 1) * width + x)
    for y in range(height):
        push(y * width)
        push(y * width + width - 1)

    while stack:
        index = stack.pop()
        x = index % width
        y = index // width
        if x > 0:
            push(index - 1)
        if x + 1 < width:
            push(index + 1)
        if y > 0:
            push(index - width)
        if y + 1 < height:
            push(index + width)

    out = image.copy()
    dst = out.load()
    for y in range(height):
        row = y * width
        for x in range(width):
            index = row + x
            r, g, b, a = src[x, y]
            if outside[index]:
                dst[x, y] = (0, 0, 0, 0)
                continue
            spread = max(r, g, b) - min(r, g, b)
            if min(r, g, b) >= 214 and spread <= 24:
                touches_outside = False
                for yy in range(max(0, y - 1), min(height, y + 2)):
                    for xx in range(max(0, x - 1), min(width, x + 2)):
                        if outside[yy * width + xx]:
                            touches_outside = True
                            break
                    if touches_outside:
                        break
                if touches_outside:
                    alpha = max(0, min(255, int(round((255 - min(r, g, b)) * 6))))
                    dst[x, y] = (r, g, b, alpha)
    return out


def estimate_foot_anchor(image, threshold: int = 8) -> tuple[float, float]:
    import statistics

    bbox = alpha_bbox(image, threshold)
    if bbox is None:
        fail("source frame appears fully transparent")
    left, top, right, bottom = bbox
    alpha = image.getchannel("A")
    sample_top = max(top, bottom - max(8, int((bottom - top) * 0.18)))
    xs: list[int] = []
    ys: list[int] = []
    for y in range(sample_top, bottom):
        for x in range(left, right):
            if alpha.getpixel((x, y)) > threshold:
                xs.append(x)
                ys.append(y)
    if not xs:
        return ((left + right) * 0.5, float(bottom))
    return (float(statistics.median(xs)), float(max(ys)))


def remove_light_checker_background(image):
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            spread = max(r, g, b) - min(r, g, b)
            light_neutral = r > 214 and g > 214 and b > 214 and spread < 22
            near_white = r > 238 and g > 238 and b > 238
            if light_neutral or near_white:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, a)
    return image


def fit_actor_frame(source, target_size: tuple[int, int]):
    source = remove_light_checker_background(source)
    target_w, target_h = target_size
    scale = min(target_w / source.width, target_h / source.height)
    resized = source.resize((round(source.width * scale), round(source.height * scale)), Image.Resampling.LANCZOS)
    frame = Image.new("RGBA", target_size, (0, 0, 0, 0))
    paste_x = (target_w - resized.width) // 2
    paste_y = target_h - resized.height
    frame.alpha_composite(resized, (paste_x, paste_y))
    return frame


def normalize_actor_sheet_from_source(
    source_path: Path,
    output_path: Path,
    frame_size: tuple[int, int],
    target_foot_anchor: tuple[float, float],
) -> None:
    image = remove_checkerboard_background(Image.open(source_path))
    if image.width % 3 != 0:
        fail(f"source width must be divisible by 3: {rel(source_path)}")
    source_frame_w = image.width // 3
    source_frame_h = image.height
    sheet = Image.new("RGBA", (frame_size[0] * 3, frame_size[1]), (0, 0, 0, 0))
    for index in range(3):
        frame = image.crop((index * source_frame_w, 0, (index + 1) * source_frame_w, source_frame_h))
        if alpha_bbox(frame) is None:
            continue
        foot_x, foot_y = estimate_foot_anchor(frame)
        scale = min(frame_size[0] / source_frame_w, frame_size[1] / source_frame_h, 1.0)
        if scale != 1.0:
            frame = frame.resize((round(frame.width * scale), round(frame.height * scale)), Image.Resampling.LANCZOS)
            foot_x *= scale
            foot_y *= scale
        paste_x = round(index * frame_size[0] + target_foot_anchor[0] - foot_x)
        paste_y = round(target_foot_anchor[1] - foot_y)
        _safe_alpha_composite(sheet, frame, (paste_x, paste_y))
    save_png(output_path, sheet)


def normalize_actor_frame_from_source(
    source_path: Path,
    output_path: Path,
    frame_size: tuple[int, int],
    target_foot_anchor: tuple[float, float],
    scale_multiplier: float = 1.0,
) -> None:
    frame = remove_checkerboard_background(Image.open(source_path))
    if alpha_bbox(frame) is None:
        fail(f"source frame appears fully transparent: {rel(source_path)}")
    foot_x, foot_y = estimate_foot_anchor(frame)
    scale = min(frame_size[0] / frame.width, frame_size[1] / frame.height, 1.0) * max(0.01, scale_multiplier)
    if scale != 1.0:
        frame = frame.resize((round(frame.width * scale), round(frame.height * scale)), Image.Resampling.LANCZOS)
        foot_x *= scale
        foot_y *= scale
    output = Image.new("RGBA", frame_size, (0, 0, 0, 0))
    paste_x = round(target_foot_anchor[0] - foot_x)
    paste_y = round(target_foot_anchor[1] - foot_y)
    _safe_alpha_composite(output, frame, (paste_x, paste_y))
    save_png(output_path, output)


def resize_actor_canvas_from_source(
    source_path: Path,
    output_path: Path,
    frame_size: tuple[int, int],
) -> None:
    frame = remove_checkerboard_background(Image.open(source_path))
    if alpha_bbox(frame) is None:
        fail(f"source frame appears fully transparent: {rel(source_path)}")
    output = frame.resize(frame_size, Image.Resampling.LANCZOS)
    save_png(output_path, output)


def fit_transparent_cover(source, size: tuple[int, int]):
    image = source.convert("RGBA")
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = max(0, (resized.width - target_w) // 2)
    top = max(0, (resized.height - target_h) // 2)
    return resized.crop((left, top, left + target_w, top + target_h))


def fit_transparent_contain(source, size: tuple[int, int], anchor: str = "bottom"):
    image = source.convert("RGBA")
    target_w, target_h = size
    scale = min(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    frame = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (target_w - resized.width) // 2
    y = target_h - resized.height if anchor == "bottom" else (target_h - resized.height) // 2
    frame.alpha_composite(resized, (x, y))
    return frame


def normalize_enemy_sheet(source_path: Path, output_path: Path) -> None:
    image = Image.open(source_path).convert("RGBA")
    image.load()
    if image.width % 3 != 0:
        fail(f"enemy source width must be divisible by 3: {rel(source_path)}")
    source_frame_w = image.width // 3
    source_frame_h = image.height
    sheet = Image.new("RGBA", (ENEMY_FRAME_SIZE[0] * 3, ENEMY_FRAME_SIZE[1]), (0, 0, 0, 0))
    for index in range(3):
        frame = image.crop((index * source_frame_w, 0, (index + 1) * source_frame_w, source_frame_h))
        bbox = alpha_bbox(frame)
        if bbox is None:
            continue
        foot_x, foot_y = estimate_foot_anchor(frame)
        scale = min(ENEMY_FRAME_SIZE[0] / source_frame_w, ENEMY_FRAME_SIZE[1] / source_frame_h, 1.0)
        if scale != 1.0:
            frame = frame.resize((round(frame.width * scale), round(frame.height * scale)), Image.Resampling.LANCZOS)
            foot_x *= scale
            foot_y *= scale
        paste_x = round(index * ENEMY_FRAME_SIZE[0] + ENEMY_FOOT_ANCHOR[0] - foot_x)
        paste_y = round(ENEMY_FOOT_ANCHOR[1] - foot_y)
        sheet.alpha_composite(frame, (paste_x, paste_y))
    save_png(output_path, sheet)


def promote_prologue() -> None:
    source_dir = PROLOGUE_SOURCE
    if not source_dir.exists():
        fail(f"missing prologue final art: {rel(source_dir)}")
    for source in sorted(source_dir.glob("*.png")):
        image = Image.open(source).convert("RGB")
        image.load()
        save_png(PROLOGUE_TARGET / source.name, cover_resize(image, BACKGROUND_SIZE))


def promote_first_battle() -> None:
    if not FINAL_PIXEL_BATTLE.exists():
        fail(f"missing pixel battle final art: {rel(FINAL_PIXEL_BATTLE)}")
    backgrounds = {
        SOURCE_BACKGROUNDS / "battle_bg_coast_ambush.png": ASSETS / "backgrounds" / "battle_bg_coast_ambush.png",
        SOURCE_BACKGROUNDS / "narrative_beach_ambush.png": ASSETS / "backgrounds" / "narrative_beach_ambush.png",
    }
    for source, target in backgrounds.items():
        if not source.exists():
            fail(f"missing first battle background: {rel(source)}")
        image = Image.open(source).convert("RGBA")
        image.load()
        save_png(target, cover_resize(image, BACKGROUND_SIZE))

    frame_dir = SOURCE_SHEETS / "spearman_frames"
    target_dir = ASSETS / "sheets" / "spearman_frames"
    for name in ["idle_guard.png", "thrust.png", "recover.png"]:
        source = frame_dir / name
        if not source.exists():
            fail(f"missing spearman frame: {rel(source)}")
        image = Image.open(source)
        image.load()
        save_png(target_dir / name, fit_actor_frame(image, SPEARMAN_FRAME_SIZE))

    source_master = SOURCE_SHEETS / "spearman_sheet_source.png"
    if source_master.exists():
        source_image = Image.open(source_master).convert("RGBA")
        source_image.load()
        save_png(ASSETS / "sheets" / "spearman_sheet_source.png", source_image)

    enemy_source = SOURCE_SHEETS / "enemy_spearman_sheet_source.png"
    if not enemy_source.exists():
        fail(f"missing enemy spearman source: {rel(enemy_source)}")
    normalize_enemy_sheet(enemy_source, ASSETS / "sheets" / "enemy_spearman_sheet.png")


def promote_chapter3_escort_clash() -> None:
    source = SOURCE_BACKGROUNDS / "battle_bg_chapter3_escort_clash.png"
    target = ASSETS / "backgrounds" / "battle_bg_chapter3_escort_clash.png"
    if not source.exists():
        print(f"[promote-final-art] chapter3 escort clash: missing optional source {rel(source)}")
        return
    image = Image.open(source).convert("RGBA")
    image.load()
    save_png(target, cover_resize(image, BACKGROUND_SIZE))


def promote_master_veteran() -> None:
    sheet_source = SOURCE_SHEETS / "master_sheets_source.png"
    portrait_source = SOURCE_PORTRAITS / "master_portraits_source.png"
    if not sheet_source.exists():
        print(f"[promote-final-art] master veteran: missing optional source {rel(sheet_source)}")
    else:
        normalize_actor_sheet_from_source(
            sheet_source,
            ASSETS / "sheets" / "master_veteran_sheet.png",
            MASTER_FRAME_SIZE,
            MASTER_FOOT_ANCHOR,
        )
    if not portrait_source.exists():
        print(f"[promote-final-art] master veteran: missing optional source {rel(portrait_source)}")
    else:
        portrait = remove_checkerboard_background(Image.open(portrait_source))
        save_png(ASSETS / "portraits" / "master_veteran_bust.png", fit_transparent_cover(portrait, (1024, 1024)))
        save_png(ASSETS / "portraits" / "performance_master_veteran.png", fit_transparent_cover(portrait, (360, 520)))


def promote_enemy_spearman_frames() -> None:
    source_dir = SOURCE_SHEETS / "enemy_spearman_frames"
    target_dir = ASSETS / "sheets" / "enemy_spearman_frames"
    frame_names = [
        "idle_guard.png",
        "long_weapon_thrust.png",
        "recover_guard.png",
    ]
    if not source_dir.exists():
        print(f"[promote-final-art] enemy spearman frames: missing optional source {rel(source_dir)}")
        return
    for name in frame_names:
        source = source_dir / name
        if not source.exists():
            fail(f"missing enemy spearman frame: {rel(source)}")
        resize_actor_canvas_from_source(
            source,
            target_dir / name,
            ENEMY_SPEARMAN_FRAME_SIZE,
        )


def check_second_battle() -> None:
    second_candidates = sorted(FINAL.glob("**/*fishing_village*.png"))
    if second_candidates:
        print("[promote-final-art] second battle final-art candidates:")
        for path in second_candidates:
            print(f"[promote-final-art]   {rel(path)}")
    else:
        print("[promote-final-art] second battle: no fishing_village final art under art_reference/final")
    for path in [
        ASSETS / "backgrounds" / "battle_bg_fishing_village_embers.png",
        ASSETS / "backgrounds" / "narrative_fishing_village_embers.png",
    ]:
        if not path.exists():
            fail(f"missing second battle runtime asset: {rel(path)}")
        with Image.open(path) as image:
            print(f"[promote-final-art] checked {rel(path)} {image.width}x{image.height} {image.mode}")


def main() -> int:
    promote_prologue()
    promote_first_battle()
    promote_chapter3_escort_clash()
    promote_master_veteran()
    promote_enemy_spearman_frames()
    check_second_battle()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
