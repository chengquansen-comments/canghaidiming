#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from pathlib import Path

from art_asset_pipeline import get_asset_type_spec


ROOT = Path(__file__).resolve().parents[1]
PROMPT_MANIFEST = ROOT / "tables" / "art_prompt_manifest.tsv"
ASSET_MANIFEST = ROOT / "tables" / "art_asset_manifest.tsv"


COMMON_EN_STYLE = (
    "Chinese ink wash + realistic historical concept art, guofeng game key visual quality, "
    "Ming dynasty coastal military world, restrained cinematic lighting, black ink, parchment beige, "
    "muted grey, sea mist grey-blue, deep cinnabar red only in small accents, subtle dark gold, "
    "tragic but dignified, heroic restraint, old-case pressure, historically credible Ming coastal military details."
)

COMMON_ZH_STYLE = (
    "中国水墨结合写实历史概念设计，国风历史武侠游戏质感，明代海疆军务氛围，"
    "电影感但克制的光照，黑墨、宣纸米色、灰蓝海雾、少量暗朱红和暗金，"
    "悲壮但体面，强调旧案压迫和军务秩序，历史细节可信。"
)

COMMON_EN_QUALITY = (
    "Clear readable focal object, production-quality composition, strong foreground-midground-background depth, "
    "readable material contrast, no decorative clutter, readable at gameplay size."
)

COMMON_ZH_QUALITY = (
    "焦点物件清楚可读，构图达到正式游戏美术质量，前中后景层次明确，材质区分清楚，"
    "不堆装饰噪点，缩到游戏尺寸后仍要可读。"
)

COMMON_EN_NEGATIVE = (
    "No text, no title, no watermark, no logo, no modern clothing, no modern weapons, no rifle, no pistol, "
    "no cyberpunk, no sci-fi, no neon, no fantasy armor, no glowing weapon, no magic effect, no monster design, "
    "no cute chibi, no bright cartoon colors, no over-saturated color, no Japanese samurai armor, no katana focus, "
    "no European knight armor, no gore, no UI elements, no frame border."
)

COMMON_ZH_NEGATIVE = (
    "不要文字、标题、水印、logo、现代服装、现代枪械、步枪、手枪、赛博朋克、科幻霓虹、"
    "玄幻甲胄、发光武器、法术特效、怪物设计、Q版、过饱和卡通色、日本武士甲、武士刀中心构图、"
    "欧式骑士甲、血腥特写、UI 元素、边框。"
)

BATTLE_OUTPUT_SPEC_EN = "16:9 PNG, 1536x864 or higher source master, suitable to downscale to 1280x720 runtime background."
BATTLE_OUTPUT_SPEC_ZH = "输出 16:9 PNG，建议 1536x864 或更高源图，后续缩到 1280x720 运行背景。"
PROP_OUTPUT_SPEC_EN = "Square PNG, 1024x1024 or higher source master, suitable to downscale to the runtime prop export profile."
PROP_OUTPUT_SPEC_ZH = "输出正方形 PNG，建议 1024x1024 或更高源图，后续按运行道具导出规格缩放。"


def fail(message: str) -> None:
    raise SystemExit(f"[render-art-prompt] ERROR: {message}")


def read_delimited(path: Path, delimiter: str) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle, delimiter=delimiter)
        rows: list[dict[str, str]] = []
        for row in reader:
            cleaned = {str(key).strip(): (value or "").strip() for key, value in row.items() if key is not None}
            if any(value != "" for value in cleaned.values()):
                rows.append(cleaned)
        return rows


def read_tsv(path: Path) -> list[dict[str, str]]:
    return read_delimited(path, "\t")


def load_prompt_entry(asset_id: str) -> dict[str, str]:
    if not PROMPT_MANIFEST.exists():
        fail(f"missing manifest: {PROMPT_MANIFEST}")
    for row in read_tsv(PROMPT_MANIFEST):
        if row.get("asset_id", "") == asset_id:
            return row
    fail(f"asset_id not found in {PROMPT_MANIFEST}: {asset_id}")


def load_asset_entry(asset_id: str) -> dict[str, str] | None:
    if not ASSET_MANIFEST.exists():
        return None
    for row in read_tsv(ASSET_MANIFEST):
        if row.get("asset_id", "") == asset_id:
            return row
    return None


def normalize_pipe_list(raw: str) -> list[str]:
    return [part.strip() for part in raw.split("|") if part.strip()]


def ensure_terminal(text: str, terminal: str) -> str:
    stripped = text.strip()
    if stripped == "":
        return ""
    if stripped.endswith((".", "!", "?", "。", "！", "？", ";", "；", ":")):
        return stripped
    return f"{stripped}{terminal}"


def join_sentences(parts: list[str]) -> str:
    return " ".join(part.strip() for part in parts if part.strip())


def join_paragraph_en(parts: list[str]) -> str:
    return " ".join(ensure_terminal(part, ".") for part in parts if part.strip())


def join_bullets_en(parts: list[str]) -> str:
    return "; ".join(part.strip() for part in parts if part.strip())


def join_bullets_zh(parts: list[str]) -> str:
    return "；".join(part.strip() for part in parts if part.strip())


def render_battle_background_en(row: dict[str, str], asset_row: dict[str, str] | None) -> str:
    target_output = row.get("target_output", "").strip() or (asset_row or {}).get("runtime_path", "")
    source_output = (asset_row or {}).get("source_path", "")
    scene_parts = normalize_pipe_list(row.get("scene_core_en", ""))
    context_parts = normalize_pipe_list(row.get("historical_context_en", ""))
    composition_parts = normalize_pipe_list(row.get("composition_en", ""))
    focal_parts = normalize_pipe_list(row.get("focal_objects_en", ""))
    mood_parts = normalize_pipe_list(row.get("mood_palette_en", ""))
    story_line = row.get("story_line_en", "").strip() or row.get("quality_bar_en", "").strip()
    negative_extra = normalize_pipe_list(row.get("negative_extra_en", ""))
    output_spec = row.get("output_spec_en", "").strip() or BATTLE_OUTPUT_SPEC_EN

    prompt_lines = [
        "Production-quality 16:9 battle background for a Ming dynasty coastal military wuxia game.",
        "",
        "Scene:",
        join_paragraph_en(scene_parts),
        "",
        "Historical setting:",
        join_paragraph_en(context_parts),
        "",
        "Composition:",
        join_paragraph_en(composition_parts),
        "",
        "Narrative focal objects:",
        join_bullets_en(focal_parts),
        "",
        "Mood and style:",
        join_sentences([COMMON_EN_STYLE, join_bullets_en(mood_parts)]),
        "",
        "Quality:",
        join_paragraph_en([COMMON_EN_QUALITY, story_line]),
        "",
        "Output:",
        output_spec,
        "",
        "Target usage:",
        join_sentences(
            [
                f"Asset id: {row.get('asset_id', '')}.",
                f"Target node or battle: {row.get('target_hook', '').strip()}.",
                f"Target runtime path: {target_output}." if target_output else "",
                f"Formal source path: {source_output}." if source_output else "",
            ]
        ),
        "",
        "Negative:",
        join_sentences([COMMON_EN_NEGATIVE, join_bullets_en(negative_extra)]),
    ]
    return "\n".join(prompt_lines)


def render_battle_background_zh(row: dict[str, str], asset_row: dict[str, str] | None) -> str:
    target_output = row.get("target_output", "").strip() or (asset_row or {}).get("runtime_path", "")
    source_output = (asset_row or {}).get("source_path", "")
    scene_parts = normalize_pipe_list(row.get("scene_core_zh", ""))
    context_parts = normalize_pipe_list(row.get("historical_context_zh", ""))
    composition_parts = normalize_pipe_list(row.get("composition_zh", ""))
    focal_parts = normalize_pipe_list(row.get("focal_objects_zh", ""))
    mood_parts = normalize_pipe_list(row.get("mood_palette_zh", ""))
    story_line = row.get("story_line_zh", "").strip() or row.get("quality_bar_zh", "").strip()
    negative_extra = normalize_pipe_list(row.get("negative_extra_zh", ""))
    output_spec = row.get("output_spec_zh", "").strip() or BATTLE_OUTPUT_SPEC_ZH

    prompt_lines = [
        "明代海疆军务题材的 16:9 横版战斗背景，用于历史武侠游戏正式源画。",
        "",
        "场景：",
        join_bullets_zh(scene_parts) + "。",
        "",
        "历史语境：",
        join_bullets_zh(context_parts) + "。",
        "",
        "构图要求：",
        join_bullets_zh(composition_parts) + "。",
        "",
        "叙事焦点：",
        join_bullets_zh(focal_parts) + "。",
        "",
        "风格与情绪：",
        join_sentences([COMMON_ZH_STYLE, join_bullets_zh(mood_parts)]),
        "",
        "质量要求：",
        join_sentences([COMMON_ZH_QUALITY, story_line]),
        "",
        "输出要求：",
        output_spec,
        "",
        "目标用途：",
        join_sentences(
            [
                f"资产 id：{row.get('asset_id', '')}。",
                f"目标节点 / 战斗：{row.get('target_hook', '').strip()}。",
                f"目标运行路径：{target_output}。" if target_output else "",
                f"正式源图路径：{source_output}。" if source_output else "",
            ]
        ),
        "",
        "负向约束：",
        join_sentences([COMMON_ZH_NEGATIVE, join_bullets_zh(negative_extra)]),
    ]
    return "\n".join(prompt_lines)


def render_narrative_background_en(row: dict[str, str], asset_row: dict[str, str] | None) -> str:
    return render_battle_background_en(row, asset_row).replace("battle background", "narrative background").replace("Target node or battle", "Target node")


def render_narrative_background_zh(row: dict[str, str], asset_row: dict[str, str] | None) -> str:
    return render_battle_background_zh(row, asset_row).replace("横版战斗背景", "叙事场景背景").replace("目标节点 / 战斗", "目标节点")


def render_narrative_prop_en(row: dict[str, str], asset_row: dict[str, str] | None) -> str:
    target_output = row.get("target_output", "").strip() or (asset_row or {}).get("runtime_path", "")
    source_output = (asset_row or {}).get("source_path", "")
    scene_parts = normalize_pipe_list(row.get("scene_core_en", ""))
    context_parts = normalize_pipe_list(row.get("historical_context_en", ""))
    composition_parts = normalize_pipe_list(row.get("composition_en", ""))
    focal_parts = normalize_pipe_list(row.get("focal_objects_en", ""))
    mood_parts = normalize_pipe_list(row.get("mood_palette_en", ""))
    story_line = row.get("story_line_en", "").strip() or row.get("quality_bar_en", "").strip()
    negative_extra = normalize_pipe_list(row.get("negative_extra_en", ""))
    output_spec = row.get("output_spec_en", "").strip() or PROP_OUTPUT_SPEC_EN

    prompt_lines = [
        "Production-quality square narrative prop illustration for a Ming dynasty coastal military wuxia game.",
        "",
        "Subject:",
        join_paragraph_en(scene_parts),
        "",
        "Historical setting:",
        join_paragraph_en(context_parts),
        "",
        "Composition:",
        join_paragraph_en(composition_parts),
        "",
        "Focal objects:",
        join_bullets_en(focal_parts),
        "",
        "Mood and style:",
        join_sentences([COMMON_EN_STYLE, join_bullets_en(mood_parts)]),
        "",
        "Quality:",
        join_paragraph_en([COMMON_EN_QUALITY, story_line]),
        "",
        "Output:",
        output_spec,
        "",
        "Target usage:",
        join_sentences(
            [
                f"Asset id: {row.get('asset_id', '')}.",
                f"Target node: {row.get('target_hook', '').strip()}.",
                f"Target runtime path: {target_output}." if target_output else "",
                f"Formal source path: {source_output}." if source_output else "",
            ]
        ),
        "",
        "Negative:",
        join_sentences([COMMON_EN_NEGATIVE, join_bullets_en(negative_extra)]),
    ]
    return "\n".join(prompt_lines)


def render_narrative_prop_zh(row: dict[str, str], asset_row: dict[str, str] | None) -> str:
    target_output = row.get("target_output", "").strip() or (asset_row or {}).get("runtime_path", "")
    source_output = (asset_row or {}).get("source_path", "")
    scene_parts = normalize_pipe_list(row.get("scene_core_zh", ""))
    context_parts = normalize_pipe_list(row.get("historical_context_zh", ""))
    composition_parts = normalize_pipe_list(row.get("composition_zh", ""))
    focal_parts = normalize_pipe_list(row.get("focal_objects_zh", ""))
    mood_parts = normalize_pipe_list(row.get("mood_palette_zh", ""))
    story_line = row.get("story_line_zh", "").strip() or row.get("quality_bar_zh", "").strip()
    negative_extra = normalize_pipe_list(row.get("negative_extra_zh", ""))
    output_spec = row.get("output_spec_zh", "").strip() or PROP_OUTPUT_SPEC_ZH

    prompt_lines = [
        "明代海疆军务题材的正方形叙事道具图，用于历史武侠游戏正式源画。",
        "",
        "主体：",
        join_bullets_zh(scene_parts) + "。",
        "",
        "历史语境：",
        join_bullets_zh(context_parts) + "。",
        "",
        "构图要求：",
        join_bullets_zh(composition_parts) + "。",
        "",
        "焦点物件：",
        join_bullets_zh(focal_parts) + "。",
        "",
        "风格与情绪：",
        join_sentences([COMMON_ZH_STYLE, join_bullets_zh(mood_parts)]),
        "",
        "质量要求：",
        join_sentences([COMMON_ZH_QUALITY, story_line]),
        "",
        "输出要求：",
        output_spec,
        "",
        "目标用途：",
        join_sentences(
            [
                f"资产 id：{row.get('asset_id', '')}。",
                f"目标节点：{row.get('target_hook', '').strip()}。",
                f"目标运行路径：{target_output}。" if target_output else "",
                f"正式源图路径：{source_output}。" if source_output else "",
            ]
        ),
        "",
        "负向约束：",
        join_sentences([COMMON_ZH_NEGATIVE, join_bullets_zh(negative_extra)]),
    ]
    return "\n".join(prompt_lines)


RENDERERS = {
    "battle_background": (render_battle_background_en, render_battle_background_zh),
    "narrative_background": (render_narrative_background_en, render_narrative_background_zh),
    "narrative_prop": (render_narrative_prop_en, render_narrative_prop_zh),
}


def render_prompt(asset_id: str, language: str) -> str:
    row = load_prompt_entry(asset_id)
    asset_row = load_asset_entry(asset_id)
    prompt_type = row.get("prompt_type", "").strip()
    spec = get_asset_type_spec(prompt_type)
    renderer_key = spec.prompt_renderer
    if renderer_key is None:
        fail(f"prompt_type '{prompt_type}' does not have a configured prompt renderer")
    renderer = RENDERERS.get(renderer_key)
    if renderer is None:
        supported = ", ".join(sorted(RENDERERS))
        fail(f"unsupported prompt renderer '{renderer_key}' for prompt_type '{prompt_type}'. Supported renderers: {supported}")

    en_renderer, zh_renderer = renderer
    en_prompt = en_renderer(row, asset_row)
    zh_prompt = zh_renderer(row, asset_row)

    header = [
        f"# {asset_id}",
        "",
        f"- prompt_type: `{prompt_type}`",
        f"- subject: {row.get('subject_label', '').strip()}",
        f"- target_hook: `{row.get('target_hook', '').strip()}`",
    ]
    if asset_row:
        header.append(f"- runtime_path: `{asset_row.get('runtime_path', '').strip()}`")
    if language == "en":
        return "\n".join(header + ["", "## EN", "", "```text", en_prompt, "```"])
    if language == "zh":
        return "\n".join(header + ["", "## ZH", "", "```text", zh_prompt, "```"])
    return "\n".join(
        header
        + [
            "",
            "## EN",
            "",
            "```text",
            en_prompt,
            "```",
            "",
            "## ZH",
            "",
            "```text",
            zh_prompt,
            "```",
        ]
    )


def render_prompt_compact(asset_id: str, language: str) -> str:
    row = load_prompt_entry(asset_id)
    prompt_type = row.get("prompt_type", "").strip()
    spec = get_asset_type_spec(prompt_type)
    renderer_key = spec.prompt_renderer
    if renderer_key is None:
        fail(f"prompt_type '{prompt_type}' does not have a configured prompt renderer")

    target_output = row.get("target_output", "").strip()
    scene_en = join_paragraph_en(normalize_pipe_list(row.get("scene_core_en", "")))
    context_en = join_paragraph_en(normalize_pipe_list(row.get("historical_context_en", "")))
    composition_en = join_paragraph_en(normalize_pipe_list(row.get("composition_en", "")))
    focal_en = join_bullets_en(normalize_pipe_list(row.get("focal_objects_en", "")))
    mood_en = join_bullets_en(normalize_pipe_list(row.get("mood_palette_en", "")))
    story_en = row.get("story_line_en", "").strip()
    negative_en = join_bullets_en(normalize_pipe_list(row.get("negative_extra_en", "")))

    scene_zh = join_bullets_zh(normalize_pipe_list(row.get("scene_core_zh", "")))
    context_zh = join_bullets_zh(normalize_pipe_list(row.get("historical_context_zh", "")))
    composition_zh = join_bullets_zh(normalize_pipe_list(row.get("composition_zh", "")))
    focal_zh = join_bullets_zh(normalize_pipe_list(row.get("focal_objects_zh", "")))
    mood_zh = join_bullets_zh(normalize_pipe_list(row.get("mood_palette_zh", "")))
    story_zh = row.get("story_line_zh", "").strip()
    negative_zh = join_bullets_zh(normalize_pipe_list(row.get("negative_extra_zh", "")))

    en_prompt = " ".join(
        part
        for part in [
            f"Production-quality 16:9 {renderer_key.replace('_', ' ')} for a Ming dynasty coastal military wuxia game.",
            scene_en,
            context_en,
            composition_en,
            f"Focal objects: {focal_en}." if focal_en else "",
            f"Mood: {mood_en}." if mood_en else "",
            COMMON_EN_STYLE,
            COMMON_EN_QUALITY,
            story_en,
            f"Target runtime path: {target_output}." if target_output else "",
            COMMON_EN_NEGATIVE,
            negative_en,
        ]
        if part
    )

    zh_prompt = " ".join(
        part
        for part in [
            f"明代海疆军务题材的16:9{renderer_key.replace('_', '')}正式源画。",
            scene_zh + "。" if scene_zh else "",
            context_zh + "。" if context_zh else "",
            composition_zh + "。" if composition_zh else "",
            f"叙事焦点：{focal_zh}。" if focal_zh else "",
            COMMON_ZH_STYLE,
            mood_zh,
            COMMON_ZH_QUALITY,
            story_zh,
            f"目标运行路径：{target_output}。" if target_output else "",
            COMMON_ZH_NEGATIVE,
            negative_zh,
        ]
        if part
    )

    if language == "en":
        return en_prompt
    if language == "zh":
        return zh_prompt
    return "\n\n".join([en_prompt, zh_prompt])


def main() -> int:
    parser = argparse.ArgumentParser(description="Render a standardized art prompt from tables/art_prompt_manifest.tsv.")
    parser.add_argument("asset_id", help="Prompt asset id")
    parser.add_argument("--lang", choices=["both", "en", "zh"], default="both")
    parser.add_argument("--style", choices=["full", "compact"], default="full")
    args = parser.parse_args()
    if args.style == "compact":
        print(render_prompt_compact(args.asset_id, args.lang))
    else:
        print(render_prompt(args.asset_id, args.lang))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
