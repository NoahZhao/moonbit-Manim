#!/usr/bin/env python3
"""Render the MoonManim proposal markdown as a paper-style Chinese PDF."""

from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    HRFlowable,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "docs" / "project-proposal.zh-CN.md"
DEFAULT_OUTPUT = ROOT / "output" / "pdf" / "moonmanim-project-proposal.pdf"

BODY_FONT = "/System/Library/Fonts/Supplemental/Songti.ttc"
HEADING_FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
MONO_FONT = "/System/Library/Fonts/Supplemental/Andale Mono.ttf"

INK = colors.HexColor("#1D2935")
MUTED = colors.HexColor("#5F6B76")
ACCENT = colors.HexColor("#176B87")
LIGHT_ACCENT = colors.HexColor("#EAF3F5")
RULE = colors.HexColor("#C8D5DA")
CODE_BG = colors.HexColor("#F3F6F7")


def register_fonts() -> None:
    # Songti.ttc index 6 is the regular Simplified Chinese face. Index 0 is Black.
    pdfmetrics.registerFont(TTFont("Songti", BODY_FONT, subfontIndex=6))
    pdfmetrics.registerFont(TTFont("Heiti", HEADING_FONT, subfontIndex=0))
    if Path(MONO_FONT).exists():
        pdfmetrics.registerFont(TTFont("Mono", MONO_FONT))
    else:
        pdfmetrics.registerFont(TTFont("Mono", BODY_FONT, subfontIndex=0))


def inline_markup(value: str) -> str:
    """Convert the small inline Markdown subset used by the proposal."""
    token = re.compile(
        r"(\[([^\]]+)\]\(([^)]+)\)|`([^`]+)`|\*\*([^*]+)\*\*|\*([^*]+)\*)"
    )
    out: list[str] = []
    cursor = 0
    for match in token.finditer(value):
        out.append(html.escape(value[cursor : match.start()]))
        if match.group(1).startswith("["):
            label = inline_markup(match.group(2))
            href = html.escape(match.group(3), quote=True)
            out.append(f'<link href="{href}" color="#176B87"><u>{label}</u></link>')
        elif match.group(4) is not None:
            out.append(f'<font name="Mono" size="8.5">{html.escape(match.group(4))}</font>')
        elif match.group(5) is not None:
            out.append(f"<b>{html.escape(match.group(5))}</b>")
        else:
            out.append(f"<i>{html.escape(match.group(6))}</i>")
        cursor = match.end()
    out.append(html.escape(value[cursor:]))
    return "".join(out)


def paragraph(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(inline_markup(text), style)


def is_table_start(lines: list[str], index: int) -> bool:
    if index + 1 >= len(lines):
        return False
    return (
        lines[index].strip().startswith("|")
        and lines[index + 1].strip().startswith("|")
        and bool(re.search(r"\|\s*:?-{3,}", lines[index + 1]))
    )


def split_table_row(line: str) -> list[str]:
    value = line.strip().strip("|")
    return [cell.strip() for cell in value.split("|")]


def make_table(rows: list[list[str]], styles: dict[str, ParagraphStyle]) -> Table:
    column_count = max(len(row) for row in rows)
    normalized = [row + [""] * (column_count - len(row)) for row in rows]
    data = []
    for row_index, row in enumerate(normalized):
        cell_style = styles["table_header"] if row_index == 0 else styles["table"]
        data.append([paragraph(cell, cell_style) for cell in row])
    available = 170 * mm
    if column_count == 3:
        widths = [available * 0.22, available * 0.22, available * 0.56]
    else:
        widths = [available / column_count] * column_count
    table = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), ACCENT),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("GRID", (0, 0), (-1, -1), 0.35, RULE),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8FAFB")]),
                ("LEFTPADDING", (0, 0), (-1, -1), 7),
                ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    return table


def build_styles() -> dict[str, ParagraphStyle]:
    sample = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "TitleCN", parent=sample["Title"], fontName="Heiti", fontSize=21,
            leading=29, alignment=TA_CENTER, textColor=INK, spaceAfter=5 * mm,
        ),
        "subtitle": ParagraphStyle(
            "SubtitleCN", parent=sample["Normal"], fontName="Songti", fontSize=10.5,
            leading=16, alignment=TA_CENTER, textColor=MUTED, spaceAfter=7 * mm,
        ),
        "h2": ParagraphStyle(
            "H2CN", parent=sample["Heading2"], fontName="Heiti", fontSize=14,
            leading=20, textColor=ACCENT, spaceBefore=7 * mm, spaceAfter=3 * mm,
            keepWithNext=True,
        ),
        "h3": ParagraphStyle(
            "H3CN", parent=sample["Heading3"], fontName="Heiti", fontSize=11.5,
            leading=17, textColor=INK, spaceBefore=4 * mm, spaceAfter=2 * mm,
            keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "BodyCN", parent=sample["BodyText"], fontName="Songti", fontSize=10.5,
            leading=18, alignment=TA_LEFT, textColor=INK, spaceAfter=3.2 * mm,
            firstLineIndent=2 * 10.5,
        ),
        "body_no_indent": ParagraphStyle(
            "BodyNoIndentCN", parent=sample["BodyText"], fontName="Songti", fontSize=10.5,
            leading=18, alignment=TA_LEFT, textColor=INK, spaceAfter=3.2 * mm,
        ),
        "bullet": ParagraphStyle(
            "BulletCN", parent=sample["BodyText"], fontName="Songti", fontSize=10.2,
            leading=17, alignment=TA_LEFT, textColor=INK, leftIndent=5 * mm,
            firstLineIndent=0, spaceAfter=1.5 * mm,
        ),
        "table": ParagraphStyle(
            "TableCN", parent=sample["BodyText"], fontName="Songti", fontSize=8.8,
            leading=13, textColor=INK, alignment=TA_LEFT,
        ),
        "table_header": ParagraphStyle(
            "TableHeaderCN", parent=sample["BodyText"], fontName="Heiti", fontSize=8.8,
            leading=13, textColor=colors.white, alignment=TA_LEFT,
        ),
        "code": ParagraphStyle(
            "CodeCN", parent=sample["Code"], fontName="Mono", fontSize=8.2,
            leading=12, textColor=INK, leftIndent=4 * mm, rightIndent=4 * mm,
            spaceBefore=2 * mm, spaceAfter=4 * mm,
        ),
    }


def parse_markdown(source: Path, styles: dict[str, ParagraphStyle]) -> list[object]:
    lines = source.read_text(encoding="utf-8").splitlines()
    story: list[object] = []
    i = 0
    first_heading = True
    while i < len(lines):
        line = lines[i].rstrip()
        if not line.strip():
            i += 1
            continue
        if line.startswith("```"):
            i += 1
            code_lines = []
            while i < len(lines) and not lines[i].startswith("```"):
                code_lines.append(lines[i])
                i += 1
            i += 1
            story.append(Preformatted("\n".join(code_lines), styles["code"], maxLineLength=110))
            continue
        if line.startswith("# "):
            title = line[2:].strip()
            story.append(Paragraph(inline_markup(title), styles["title"]))
            story.append(Paragraph("项目申报书 · MoonBit 数学可视化", styles["subtitle"]))
            story.append(HRFlowable(width="100%", thickness=1.0, color=ACCENT, spaceAfter=6 * mm))
            first_heading = False
            i += 1
            continue
        if line.startswith("## "):
            story.append(Paragraph(inline_markup(line[3:].strip()), styles["h2"]))
            i += 1
            continue
        if line.startswith("### "):
            story.append(Paragraph(inline_markup(line[4:].strip()), styles["h3"]))
            i += 1
            continue
        if is_table_start(lines, i):
            rows = [split_table_row(lines[i])]
            i += 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(split_table_row(lines[i]))
                i += 1
            story.append(Spacer(1, 1.5 * mm))
            story.append(make_table(rows, styles))
            story.append(Spacer(1, 3 * mm))
            continue
        if re.match(r"^[-*] ", line):
            items = []
            while i < len(lines) and re.match(r"^[-*] ", lines[i].strip()):
                items.append(ListItem(paragraph(lines[i].strip()[2:], styles["bullet"]), leftIndent=0))
                i += 1
            story.append(ListFlowable(items, bulletType="bullet", start="circle", leftIndent=7 * mm, bulletFontName="Heiti", bulletFontSize=7))
            story.append(Spacer(1, 1.5 * mm))
            continue
        if re.match(r"^\d+\. ", line):
            items = []
            while i < len(lines) and re.match(r"^\d+\. ", lines[i].strip()):
                content = re.sub(r"^\d+\. ", "", lines[i].strip())
                items.append(ListItem(paragraph(content, styles["bullet"]), leftIndent=0))
                i += 1
            story.append(ListFlowable(items, bulletType="1", start="1", leftIndent=7 * mm))
            story.append(Spacer(1, 1.5 * mm))
            continue
        parts = [line.strip()]
        i += 1
        while i < len(lines):
            candidate = lines[i].rstrip()
            if (
                not candidate.strip()
                or candidate.startswith(("# ", "## ", "### ", "```"))
                or is_table_start(lines, i)
                or re.match(r"^[-*] ", candidate)
                or re.match(r"^\d+\. ", candidate)
            ):
                break
            parts.append(candidate.strip())
            i += 1
        style = styles["body_no_indent"] if first_heading else styles["body"]
        story.append(paragraph(" ".join(parts), style))
        first_heading = False
    return story


def draw_page(canvas, doc) -> None:
    canvas.saveState()
    width, height = A4
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.4)
    canvas.line(doc.leftMargin, height - 13 * mm, width - doc.rightMargin, height - 13 * mm)
    canvas.setFont("Heiti", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(doc.leftMargin, height - 10 * mm, "MoonManim · 项目申报书")
    canvas.drawRightString(width - doc.rightMargin, 10 * mm, f"{doc.page}")
    canvas.restoreState()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    register_fonts()
    styles = build_styles()
    document = SimpleDocTemplate(
        str(args.output), pagesize=A4, rightMargin=20 * mm, leftMargin=20 * mm,
        topMargin=20 * mm, bottomMargin=17 * mm, title="MoonManim 项目申报书",
        author="NoahZhao",
    )
    document.build(parse_markdown(args.source, styles), onFirstPage=draw_page, onLaterPages=draw_page)
    print(args.output)


if __name__ == "__main__":
    main()
