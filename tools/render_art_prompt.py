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
CHROMA_KEY_REQUIRED_TYPES = {"battle_action_sheet", "battle_portrait"}
CHROMA_EN_RULE = "Use chroma key background: pure bright green #00FF00, single flat color, no shadows, no gradients."
CHROMA_ZH_RULE = "抠图背景必须使用纯亮绿 #00FF00，背景单一纯色，无阴影、无渐变。"


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


def needs_chroma_key(row: dict[str, str]) -> bool:
    return row.get("prompt_type", "").strip() in CHROMA_KEY_REQUIRED_TYPES


def prompt_lead_en(prompt_type: str) -> str:
    if prompt_type == "battle_action_sheet":
        return "Production-quality battle action sheet for a Ming dynasty coastal military wuxia game."
    if prompt_type == "battle_portrait":
        return "Production-quality battle portrait for a Ming dynasty coastal military wuxia game."
    if prompt_type == "narrative_background":
        return "Production-quality narrative background for a Ming dynasty coastal military wuxia game."
    if prompt_type == "narrative_prop":
        return "Production-quality narrative prop illustration for a Ming dynasty coastal military wuxia game."
    return "Production-quality battle background for a Ming dynasty coastal military wuxia game."


def prompt_lead_zh(prompt_type: str) -> str:
    if prompt_type == "battle_action_sheet":
        return "明代海疆军务题材的正式战斗动作 sheet，用于历史武侠游戏源画。"
    if prompt_type == "battle_portrait":
        return "明代海疆军务题材的正式战斗头像，用于历史武侠游戏源画。"
    if prompt_type == "narrative_background":
        return "明代海疆军务题材的正式叙事背景，用于历史武侠游戏源画。"
    if prompt_type == "narrative_prop":
        return "明代海疆军务题材的正式叙事道具图，用于历史武侠游戏源画。"
    return "明代海疆军务题材的正式战斗背景，用于历史武侠游戏源画。"


def format_requirement_en(prompt_type: str) -> str:
    if prompt_type == "battle_action_sheet":
        return (
            "Total canvas must be exactly 1536x1536. "
            "Layout must be one vertical 3-frame column. Each frame must be exactly 1536x512. "
            "The ground-contact foot anchor must stay at the same vertical baseline across all three frames with no floating or sliding."
        )
    if prompt_type == "battle_portrait":
        return "Total canvas must be exactly 1024x1024 square."
    return ""


def format_requirement_zh(prompt_type: str) -> str:
    if prompt_type == "battle_action_sheet":
        return "总画布必须严格 1536x1536，必须为纵向三叠单列，三帧一列，每帧严格 1536x512。三帧脚底接地锚点必须保持同一垂直基线，不要漂浮，不要滑步错位。"
    if prompt_type == "battle_portrait":
        return "总画布必须严格 1024x1024 方形。"
    return ""


def style_requirement_en(prompt_type: str) -> str:
    if prompt_type == "battle_action_sheet":
        return (
            "Grounded Ming dynasty coastal military wuxia realism. Dark ink-wash realistic historical concept art with rugged campaign-worn "
            "texture, old-case pressure, and restrained tragic atmosphere. Use practical Ming coastal military materials: battle-worn lamellar "
            "armor, patched cloth layers, frayed robe edges, mud-stained trousers, worn leather boots, salt-weathered fabric, aged metal, old "
            "field gear, rough binding cords, restrained dirty cinnabar red accents, muted dark blue-grey, black ink, parchment beige, muted grey, "
            "and subtle dark gold details. The design must feel practical, dangerous, historically credible, and human, with strong readable "
            "silhouette, clear material contrast, and production-ready game readability. Apply style to costume, weapon, face rendering, fabric "
            "edges, armor texture, and small military details only. Keep the character isolated on flat chroma key green with no environment "
            "painting, no scenic backdrop, and no background atmosphere."
        )
    if prompt_type == "battle_portrait":
        return (
            "Chinese ink wash influence applied to face, costume texture, and restrained color design only. "
            "Keep the portrait isolated on flat chroma key green with no environment painting, no scenic backdrop, "
            "and no atmospheric background treatment."
        )
    return COMMON_EN_STYLE


def style_requirement_zh(prompt_type: str) -> str:
    if prompt_type == "battle_action_sheet":
        return (
            "整体风格为扎实的明代海疆军务武侠写实。深墨水墨结合写实历史概念设计，带粗粝行军磨损质感、旧案压迫、克制悲怆气氛。"
            "材质使用实用明代海防军务体系：战损札甲、补丁布层、磨损衣缘、泥渍裤腿、旧皮靴、盐蚀织物、陈旧金属、老旧行军装备、"
            "粗绑绳结、克制偏脏暗朱红点缀、低饱和深灰蓝、黑墨、宣纸米色、低饱和灰、少量暗金细节。整体必须显得实用、危险、"
            "历史可信、且具有人味，轮廓强可读、材质反差清晰、达到正式游戏可读性。风格只作用在服饰、兵器、面部刻画、布料边缘、"
            "甲胄纹理和小型军务细节上。角色必须孤立在纯绿抠图底上，不要场景绘制、不要背景叙事、不要背景气氛。"
        )
    if prompt_type == "battle_portrait":
        return (
            "中国水墨气质只用于面部、服饰材质和克制配色。"
            "头像必须孤立在纯绿抠图底上，不要场景绘制、不要背景叙事、不要气氛化底色。"
        )
    return COMMON_ZH_STYLE


def quality_requirement_en(prompt_type: str) -> str:
    if prompt_type == "battle_action_sheet":
        return (
            "Clear readable focal character, production-quality composition, strong character-shape depth, readable material contrast, "
            "no decorative clutter, readable at gameplay size, production-ready sprite readability, stable proportions across frames."
        )
    if prompt_type == "battle_portrait":
        return (
            "Clear readable portrait silhouette, centered face readability, readable material contrast, "
            "no decorative clutter, and no scene-style depth staging."
        )
    return COMMON_EN_QUALITY


def quality_requirement_zh(prompt_type: str) -> str:
    if prompt_type == "battle_action_sheet":
        return "角色焦点清楚可读，构图达到正式游戏美术质量，角色形体层次强，材质区分清楚，不堆装饰噪点，缩到游戏尺寸后仍可读，达到正式 sprite 生产可读性，三帧比例稳定。"
    if prompt_type == "battle_portrait":
        return "头像轮廓清楚，面部居中可读，材质区分清楚，不堆装饰噪点，不要场景式纵深。"
    return COMMON_ZH_QUALITY


def output_spec_en(prompt_type: str, asset_row: dict[str, str] | None) -> str:
    runtime_path = (asset_row or {}).get("runtime_path", "")
    if prompt_type == "battle_action_sheet":
        return "Output one 1536x1536 PNG source master: vertical 3-stack action sheet, 3 rows in one column, each frame exactly 1536x512, with pure #00FF00 chroma key background."
    if prompt_type == "battle_portrait":
        return "Output 1024x1024 PNG source master for a square portrait with chroma key background #00FF00."
    if prompt_type in {"battle_background", "narrative_background"}:
        return BATTLE_OUTPUT_SPEC_EN
    if prompt_type == "narrative_prop":
        return PROP_OUTPUT_SPEC_EN
    return f"Output asset master targeting {runtime_path}." if runtime_path else BATTLE_OUTPUT_SPEC_EN


def output_spec_zh(prompt_type: str, asset_row: dict[str, str] | None) -> str:
    runtime_path = (asset_row or {}).get("runtime_path", "")
    if prompt_type == "battle_action_sheet":
        return "输出一张 1536x1536 PNG 源图：纵向三叠动作 sheet，三帧一列，每帧严格 1536x512，抠图背景必须使用纯亮绿 #00FF00。"
    if prompt_type == "battle_portrait":
        return "输出 1024x1024 PNG 源图，方形头像，抠图背景必须使用纯亮绿 #00FF00。"
    if prompt_type in {"battle_background", "narrative_background"}:
        return BATTLE_OUTPUT_SPEC_ZH
    if prompt_type == "narrative_prop":
        return PROP_OUTPUT_SPEC_ZH
    return f"输出目标资源 {runtime_path} 的源图。" if runtime_path else BATTLE_OUTPUT_SPEC_ZH


def apply_chroma_prompt_rules_en(parts: list[str], prompt_type: str) -> list[str]:
    if prompt_type not in CHROMA_KEY_REQUIRED_TYPES:
        return parts
    updated: list[str] = []
    for part in parts:
        part = part.replace("Transparent-background", "Chroma-key")
        if prompt_type == "battle_action_sheet":
            part = part.replace("horizontal sprite sheet, 3 frames in one row", "vertical 3-stack sprite sheet, 3 frames in one column, each frame 1536x512")
            part = part.replace("3 frames in one row", "3 frames in one column")
        part = part.replace("Subtle transparent or restrained parchment background allowed", CHROMA_EN_RULE)
        part = part.replace("Subtle transparent or restrained parchment background permitted", CHROMA_EN_RULE)
        part = part.replace("transparent background allowed", CHROMA_EN_RULE)
        updated.append(part)
    if all(CHROMA_EN_RULE not in part for part in updated):
        updated.append(CHROMA_EN_RULE)
    return updated


def apply_chroma_prompt_rules_zh(parts: list[str], prompt_type: str) -> list[str]:
    if prompt_type not in CHROMA_KEY_REQUIRED_TYPES:
        return parts
    chroma_rule = CHROMA_ZH_RULE.rstrip("。")
    updated: list[str] = []
    for part in parts:
        if prompt_type == "battle_action_sheet":
            part = part.replace("透明背景横向 sprite sheet，三帧一行", "纯亮绿抠图纵向三叠 sprite sheet，三帧一列，每帧 1536x512")
            part = part.replace("横向 sprite sheet", "纵向三叠 sprite sheet")
            part = part.replace("三帧一行", "三帧一列")
        part = part.replace("透明背景横向 sprite sheet", "纯亮绿抠图纵向三叠 sprite sheet")
        part = part.replace("允许透明背景或克制宣纸底", chroma_rule)
        part = part.replace("克制宣纸底", "纯亮绿抠图背景")
        part = part.replace("透明背景", "纯亮绿抠图背景")
        updated.append(part)
    if all(chroma_rule not in part for part in updated):
        updated.append(chroma_rule)
    return updated


def dedupe_compact_composition_en(prompt_type: str, composition: str) -> str:
    if prompt_type != "battle_action_sheet":
        return composition
    return composition


def dedupe_compact_composition_zh(prompt_type: str, composition: str) -> str:
    if prompt_type != "battle_action_sheet":
        return composition
    return composition


def clean_semicolon_items(raw: str) -> str:
    parts = [part.strip() for part in raw.split(";")]
    parts = [part for part in parts if part]
    return "; ".join(parts)


def dedupe_compact_negative_en(prompt_type: str, negative_extra: str, chroma_required: bool) -> str:
    cleaned = negative_extra
    duplicates = [
        "no katana focus",
        "no samurai armor",
        "no Japanese samurai armor",
        "no modern tactical gear",
        "no modern clothing",
        "no modern weapons",
    ]
    chroma_duplicates = [
        "no non-green background",
        "no transparency trick backgrounds",
        "no gradients",
        "no cast shadows",
    ]
    for item in duplicates:
        cleaned = cleaned.replace(item, "")
    if prompt_type == "battle_action_sheet" and chroma_required:
        for item in chroma_duplicates:
            cleaned = cleaned.replace(item, "")
    return clean_semicolon_items(cleaned)


def dedupe_compact_negative_zh(prompt_type: str, negative_extra: str, chroma_required: bool) -> str:
    cleaned = negative_extra
    duplicates = [
        "不要武士刀中心构图",
        "不要日本武士甲",
        "不要现代服装",
        "不要现代枪械",
    ]
    chroma_duplicates = ["不要非绿色背景", "不要伪透明底", "不要渐变底", "不要投影"]
    for item in duplicates:
        cleaned = cleaned.replace(item, "")
    if prompt_type == "battle_action_sheet" and chroma_required:
        for item in chroma_duplicates:
            cleaned = cleaned.replace(item, "")
    parts = [part.strip() for part in cleaned.split("；")]
    parts = [part for part in parts if part]
    return "；".join(parts)


def render_battle_background_en(row: dict[str, str], asset_row: dict[str, str] | None) -> str:
    prompt_type = row.get("prompt_type", "").strip()
    target_output = row.get("target_output", "").strip() or (asset_row or {}).get("runtime_path", "")
    source_output = (asset_row or {}).get("source_path", "")
    scene_parts = normalize_pipe_list(row.get("scene_core_en", ""))
    context_parts = normalize_pipe_list(row.get("historical_context_en", ""))
    composition_parts = normalize_pipe_list(row.get("composition_en", ""))
    focal_parts = normalize_pipe_list(row.get("focal_objects_en", ""))
    mood_parts = normalize_pipe_list(row.get("mood_palette_en", ""))
    story_line = row.get("story_line_en", "").strip() or row.get("quality_bar_en", "").strip()
    negative_extra = normalize_pipe_list(row.get("negative_extra_en", ""))
    output_spec = row.get("output_spec_en", "").strip() or output_spec_en(prompt_type, asset_row)
    composition_parts = apply_chroma_prompt_rules_en(composition_parts, prompt_type)
    if prompt_type in CHROMA_KEY_REQUIRED_TYPES:
        negative_extra.append("No non-green background, no transparency trick backgrounds, no gradients, no cast shadows")

    prompt_lines = [
        prompt_lead_en(prompt_type),
        "",
        "Format requirements:",
        format_requirement_en(prompt_type),
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
        join_sentences([style_requirement_en(prompt_type), join_bullets_en(mood_parts)]),
        "",
        "Quality:",
        join_paragraph_en([quality_requirement_en(prompt_type), story_line]),
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
    prompt_type = row.get("prompt_type", "").strip()
    target_output = row.get("target_output", "").strip() or (asset_row or {}).get("runtime_path", "")
    source_output = (asset_row or {}).get("source_path", "")
    scene_parts = normalize_pipe_list(row.get("scene_core_zh", ""))
    context_parts = normalize_pipe_list(row.get("historical_context_zh", ""))
    composition_parts = normalize_pipe_list(row.get("composition_zh", ""))
    focal_parts = normalize_pipe_list(row.get("focal_objects_zh", ""))
    mood_parts = normalize_pipe_list(row.get("mood_palette_zh", ""))
    story_line = row.get("story_line_zh", "").strip() or row.get("quality_bar_zh", "").strip()
    negative_extra = normalize_pipe_list(row.get("negative_extra_zh", ""))
    output_spec = row.get("output_spec_zh", "").strip() or output_spec_zh(prompt_type, asset_row)
    composition_parts = apply_chroma_prompt_rules_zh(composition_parts, prompt_type)
    if prompt_type in CHROMA_KEY_REQUIRED_TYPES:
        negative_extra.append("不要非绿色背景、不要伪透明底、不要渐变底、不要投影")

    prompt_lines = [
        prompt_lead_zh(prompt_type),
        "",
        "版式硬约束：",
        format_requirement_zh(prompt_type),
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
        join_sentences([style_requirement_zh(prompt_type), join_bullets_zh(mood_parts)]),
        "",
        "质量要求：",
        join_sentences([quality_requirement_zh(prompt_type), story_line]),
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
    prompt_type = row.get("prompt_type", "").strip()
    target_output = row.get("target_output", "").strip() or (asset_row or {}).get("runtime_path", "")
    source_output = (asset_row or {}).get("source_path", "")
    scene_parts = normalize_pipe_list(row.get("scene_core_en", ""))
    context_parts = normalize_pipe_list(row.get("historical_context_en", ""))
    composition_parts = normalize_pipe_list(row.get("composition_en", ""))
    focal_parts = normalize_pipe_list(row.get("focal_objects_en", ""))
    mood_parts = normalize_pipe_list(row.get("mood_palette_en", ""))
    story_line = row.get("story_line_en", "").strip() or row.get("quality_bar_en", "").strip()
    negative_extra = normalize_pipe_list(row.get("negative_extra_en", ""))
    output_spec = row.get("output_spec_en", "").strip() or output_spec_en(prompt_type, asset_row)
    composition_parts = apply_chroma_prompt_rules_en(composition_parts, prompt_type)
    if prompt_type in CHROMA_KEY_REQUIRED_TYPES:
        negative_extra.append("No non-green background, no transparency trick backgrounds, no gradients, no cast shadows")

    prompt_lines = [
        prompt_lead_en(prompt_type),
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
    prompt_type = row.get("prompt_type", "").strip()
    target_output = row.get("target_output", "").strip() or (asset_row or {}).get("runtime_path", "")
    source_output = (asset_row or {}).get("source_path", "")
    scene_parts = normalize_pipe_list(row.get("scene_core_zh", ""))
    context_parts = normalize_pipe_list(row.get("historical_context_zh", ""))
    composition_parts = normalize_pipe_list(row.get("composition_zh", ""))
    focal_parts = normalize_pipe_list(row.get("focal_objects_zh", ""))
    mood_parts = normalize_pipe_list(row.get("mood_palette_zh", ""))
    story_line = row.get("story_line_zh", "").strip() or row.get("quality_bar_zh", "").strip()
    negative_extra = normalize_pipe_list(row.get("negative_extra_zh", ""))
    output_spec = row.get("output_spec_zh", "").strip() or output_spec_zh(prompt_type, asset_row)
    composition_parts = apply_chroma_prompt_rules_zh(composition_parts, prompt_type)
    if prompt_type in CHROMA_KEY_REQUIRED_TYPES:
        negative_extra.append("不要非绿色背景、不要伪透明底、不要渐变底、不要投影")

    prompt_lines = [
        prompt_lead_zh(prompt_type),
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
    "battle_portrait": (render_narrative_prop_en, render_narrative_prop_zh),
    "battle_action_sheet": (render_battle_background_en, render_battle_background_zh),
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
    chroma_required = needs_chroma_key(row)
    asset_row = load_asset_entry(asset_id)
    output_en = output_spec_en(prompt_type, asset_row)
    output_zh = output_spec_zh(prompt_type, asset_row)
    composition_en = dedupe_compact_composition_en(prompt_type, composition_en)
    composition_zh = dedupe_compact_composition_zh(prompt_type, composition_zh)
    negative_en = dedupe_compact_negative_en(prompt_type, negative_en, chroma_required)
    negative_zh = dedupe_compact_negative_zh(prompt_type, negative_zh, chroma_required)

    en_prompt = " ".join(
        part
        for part in [
            prompt_lead_en(prompt_type),
            format_requirement_en(prompt_type),
            scene_en,
            context_en,
            " ".join(apply_chroma_prompt_rules_en([composition_en], prompt_type)) if composition_en else "",
            f"Focal objects: {focal_en}." if focal_en else "",
            f"Mood: {mood_en}." if mood_en else "",
            style_requirement_en(prompt_type),
            quality_requirement_en(prompt_type),
            story_en,
            f"Target runtime path: {target_output}." if target_output else "",
            output_en,
            COMMON_EN_NEGATIVE,
            negative_en,
            "No non-green background, no transparency trick backgrounds, no gradients, no cast shadows." if chroma_required else "",
        ]
        if part
    )

    zh_prompt = " ".join(
        part
        for part in [
            prompt_lead_zh(prompt_type),
            format_requirement_zh(prompt_type),
            scene_zh + "。" if scene_zh else "",
            context_zh + "。" if context_zh else "",
            "；".join(apply_chroma_prompt_rules_zh([composition_zh], prompt_type)) + "。" if composition_zh else "",
            f"叙事焦点：{focal_zh}。" if focal_zh else "",
            style_requirement_zh(prompt_type),
            mood_zh,
            quality_requirement_zh(prompt_type),
            story_zh,
            f"目标运行路径：{target_output}。" if target_output else "",
            output_zh,
            COMMON_ZH_NEGATIVE,
            negative_zh,
            "不要非绿色背景、不要伪透明底、不要渐变底、不要投影。" if chroma_required else "",
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
