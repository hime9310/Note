# PowerPoint MCP Server 最終版 完全ガイド

> ローカルstdio型 / 外部通信ゼロ / 社内テンプレート対応 / Claudeと同等のPPTX作成能力

---

## 目次

1. [アーキテクチャと通信の仕組み](#1-アーキテクチャと通信の仕組み)
2. [前提条件・制約・審査ポイント](#2-前提条件制約審査ポイント)
3. [環境構築とディレクトリ構成](#3-環境構築とディレクトリ構成)
4. [Pythonコード全文（完全版）](#4-pythonコード全文完全版)
5. [IDE設定（VS Code / Kiro）](#5-ide設定vs-code--kiro)
6. [ツール完全一覧](#6-ツール完全一覧)
7. [社内テンプレートの調査と活用](#7-社内テンプレートの調査と活用)
8. [ワークフロー詳細とプロンプト例](#8-ワークフロー詳細とプロンプト例)
9. [Kiro Steering連携](#9-kiro-steering連携)

---

## 1. アーキテクチャと通信の仕組み

ExcelMCPサーバーと同じstdio型。外部通信ゼロ。

```
IDE（VS Code / Kiro）
    ↕ stdin/stdout（プロセス間通信のみ）
pptx_mcp_server.py（子プロセス）
    ↓ ファイル操作
.pptx（ローカル保存）/ 社内テンプレート継承
```

---

## 2. 前提条件・制約・審査ポイント

### 必要なソフトウェア

| # | ソフトウェア | 外部通信 |
|---|------------|--------|
| 1 | Python 3.10以上 | なし |
| 2 | `mcp` (pip) | なし |
| 3 | `python-pptx` (pip) | なし |

```powershell
pip install mcp python-pptx --proxy http://your-proxy:port
pip install mcp python-pptx --user   # 管理者権限なし
```

### python-pptxの能力と制約

| 機能 | 対応 |
|------|------|
| テンプレート継承（テーマ・フォント・カラー） | ✅ |
| スライド追加・レイアウト指定 | ✅ |
| テキスト（タイトル・本文・テキストボックス） | ✅ |
| 表（テーブル） | ✅ |
| 基本図形（矩形・角丸・円・矢印・菱形） | ✅ |
| 画像挿入（PNG/JPG） | ✅ |
| 図形間のコネクタ（接続線） | ✅ |
| 発表者ノート | ✅ |
| スライドコピー・複製 | ✅ |
| スライド背景色設定 | ✅ |
| テキストの段落・ランごとの書式 | ✅ |
| **SmartArtの生成** | ❌ |
| **アニメーション** | ❌ |
| **埋め込みチャート（動的）** | ⚠️ 限定的 |
| **VBAマクロ** | ❌ |

---

## 3. 環境構築とディレクトリ構成

```
project/
├── .kiro/
│   ├── settings/mcp.json
│   └── steering/pptx-workflow-guide.md
├── .vscode/mcp.json
├── mcp_servers/
│   └── pptx/
│       ├── pptx_mcp_server.py
│       ├── requirements.txt
│       └── templates/
│           └── company_template.pptx   ← 社内テンプレート
└── output/
```

**requirements.txt**
```
mcp>=1.0.0
python-pptx>=0.6.21
```

---

## 4. Pythonコード全文（完全版）

**`mcp_servers/pptx/pptx_mcp_server.py`**

```python
"""
PowerPoint MCP Server - 最終版
Claudeと同等のPPTX作成能力 / 社内テンプレート対応 / ローカルstdio型 / 外部通信ゼロ
"""

import sys
import json
from pathlib import Path
from typing import Optional, Any
from copy import deepcopy

from pptx import Presentation
from pptx.util import Inches, Pt, Emu, Cm
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.enum.shapes import MSO_SHAPE_TYPE
from pptx.oxml.ns import qn
from lxml import etree

from mcp.server.fastmcp import FastMCP

# ─────────────────────────────────────────────────────────
# 設定・初期化
# ─────────────────────────────────────────────────────────
TEMPLATE_DIR = Path(__file__).parent / "templates"
DEFAULT_TEMPLATE = TEMPLATE_DIR / "company_template.pptx"

mcp = FastMCP(name="pptx-mcp-server", version="2.0.0")

def _log(msg: str):
    print(f"[pptx-mcp] {msg}", file=sys.stderr)

def _load(filepath: str) -> Presentation:
    p = Path(filepath)
    if not p.exists():
        raise FileNotFoundError(f"ファイルが見つかりません: {filepath}")
    return Presentation(filepath)

def _save(prs: Presentation, filepath: str):
    Path(filepath).parent.mkdir(parents=True, exist_ok=True)
    prs.save(filepath)
    _log(f"保存: {filepath}")

def _rgb(hex_color: str) -> RGBColor:
    h = hex_color.lstrip("#")
    return RGBColor(int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

def _get_slide(prs: Presentation, idx: int):
    if idx < 0 or idx >= len(prs.slides):
        raise IndexError(f"スライド{idx}は範囲外（0-{len(prs.slides)-1}）")
    return prs.slides[idx]

def _align_map(align: str):
    return {
        "left": PP_ALIGN.LEFT,
        "center": PP_ALIGN.CENTER,
        "right": PP_ALIGN.RIGHT,
        "justify": PP_ALIGN.JUSTIFY
    }.get(align, PP_ALIGN.LEFT)

def _apply_text_style(run, font_size=None, font_color=None, bold=None,
                      italic=None, font_name=None):
    if font_size: run.font.size = Pt(font_size)
    if font_color: run.font.color.rgb = _rgb(font_color)
    if bold is not None: run.font.bold = bold
    if italic is not None: run.font.italic = italic
    if font_name: run.font.name = font_name

SHAPE_MAP = {
    "rectangle": 1,
    "rounded_rectangle": 5,
    "oval": 9,
    "diamond": 4,
    "triangle": 6,
    "right_arrow": 13,
    "left_arrow": 14,
    "up_arrow": 68,
    "down_arrow": 69,
    "chevron": 57,
    "pentagon": 56,
    "hexagon": 10,
    "parallelogram": 7,
    "trapezoid": 8,
    "star_4": 89,
    "star_5": 92,
    "callout": 49,
    "cloud": 178,
    "cylinder": 22,
}


# ─────────────────────────────────────────────────────────
# ■ プレゼンテーション基本操作
# ─────────────────────────────────────────────────────────

@mcp.tool()
def create_presentation(
    output_filepath: str,
    template_filepath: Optional[str] = None
) -> str:
    """
    プレゼンテーションを作成する。
    template_filepath: 社内テンプレートのパス（省略時はデフォルトテンプレートを使用）
    テンプレートのテーマ・カラー・フォント・マスタースライドが全て継承される。
    """
    try:
        tpl = template_filepath or str(DEFAULT_TEMPLATE)
        if Path(tpl).exists():
            prs = Presentation(tpl)
            source = tpl
        else:
            prs = Presentation()
            source = "ブランク"
        _save(prs, output_filepath)
        return f"✅ 作成完了: {output_filepath}\nテンプレート: {source}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def list_templates() -> str:
    """利用可能な社内テンプレート一覧を取得する。"""
    try:
        if not TEMPLATE_DIR.exists():
            return "テンプレートフォルダが存在しません"
        files = [{"name": f.name, "path": str(f)}
                 for f in sorted(TEMPLATE_DIR.glob("*.pptx"))]
        return json.dumps(files, ensure_ascii=False) if files else "テンプレートなし"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def list_layouts(filepath: str) -> str:
    """
    利用可能なスライドレイアウト一覧を取得する。
    スライド追加前に必ず実行して、使えるレイアウトのインデックスを確認すること。
    """
    try:
        prs = _load(filepath)
        layouts = []
        for i, layout in enumerate(prs.slide_layouts):
            phs = [{"idx": ph.placeholder_format.idx,
                    "type": str(ph.placeholder_format.type).split(".")[-1],
                    "name": ph.name}
                   for ph in layout.placeholders]
            layouts.append({"index": i, "name": layout.name, "placeholders": phs})
        return json.dumps(layouts, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def get_presentation_info(filepath: str) -> str:
    """プレゼンテーションの概要（スライド数・サイズ・各スライドのタイトル）を取得する。"""
    try:
        prs = _load(filepath)
        slides_info = []
        for i, slide in enumerate(prs.slides):
            title = ""
            for shape in slide.shapes:
                if shape.has_text_frame and hasattr(shape, "placeholder_format"):
                    if shape.placeholder_format and shape.placeholder_format.idx == 0:
                        title = shape.text_frame.text.strip()
                        break
            slides_info.append({"index": i, "title": title,
                                 "shape_count": len(slide.shapes)})
        return json.dumps({
            "slide_count": len(prs.slides),
            "width_inches": round(prs.slide_width.inches, 2),
            "height_inches": round(prs.slide_height.inches, 2),
            "slides": slides_info
        }, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def read_all_slides_text(filepath: str) -> str:
    """全スライドのテキストを一括取得する（内容確認・編集前の把握用）。"""
    try:
        prs = _load(filepath)
        result = []
        for i, slide in enumerate(prs.slides):
            texts = [shape.text_frame.text.strip()
                     for shape in slide.shapes
                     if shape.has_text_frame and shape.text_frame.text.strip()]
            result.append({"slide_index": i, "texts": texts})
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"❌ {e}"


# ─────────────────────────────────────────────────────────
# ■ スライド操作
# ─────────────────────────────────────────────────────────

@mcp.tool()
def add_slide(
    filepath: str,
    layout_index: int,
    title: Optional[str] = None,
    body: Optional[str] = None,
    notes: Optional[str] = None
) -> str:
    """
    スライドを末尾に追加する。
    layout_index: list_layouts で確認したインデックス
    title: タイトル（プレースホルダー idx=0）
    body: 本文。\\n で区切ると段落（箇条書き）になる
    notes: 発表者ノート
    """
    try:
        prs = _load(filepath)
        slide = prs.slides.add_slide(prs.slide_layouts[layout_index])
        if title is not None:
            for ph in slide.placeholders:
                if ph.placeholder_format.idx == 0:
                    ph.text = title
                    break
        if body is not None:
            for ph in slide.placeholders:
                if ph.placeholder_format.idx == 1:
                    tf = ph.text_frame
                    tf.clear()
                    lines = body.split("\n")
                    for j, line in enumerate(lines):
                        if j == 0:
                            tf.paragraphs[0].text = line
                        else:
                            tf.add_paragraph().text = line
                    break
        if notes is not None:
            slide.notes_slide.notes_text_frame.text = notes
        _save(prs, filepath)
        return f"✅ スライド追加（{len(prs.slides)}枚目）: {title or '(タイトルなし)'}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def duplicate_slide(filepath: str, source_slide_index: int) -> str:
    """スライドを複製して末尾に追加する。テンプレートスライドの複製に使う。"""
    try:
        prs = _load(filepath)
        src = _get_slide(prs, source_slide_index)
        # XML要素をディープコピーしてスライドリストに追加
        xml_copy = deepcopy(src._element)
        prs.slides._sldIdLst.append(xml_copy)
        _save(prs, filepath)
        return f"✅ スライド{source_slide_index}を複製（末尾に追加）"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def set_slide_background(
    filepath: str,
    slide_index: int,
    color: str
) -> str:
    """
    スライドの背景色を設定する。
    color: "#1F4E79"（ネイビー）など。白は"#FFFFFF"。
    """
    try:
        prs = _load(filepath)
        slide = _get_slide(prs, slide_index)
        background = slide.background
        fill = background.fill
        fill.solid()
        fill.fore_color.rgb = _rgb(color)
        _save(prs, filepath)
        return f"✅ 背景色設定: スライド{slide_index} → {color}"
    except Exception as e:
        return f"❌ {e}"


# ─────────────────────────────────────────────────────────
# ■ テキスト操作
# ─────────────────────────────────────────────────────────

@mcp.tool()
def set_placeholder_text(
    filepath: str,
    slide_index: int,
    placeholder_idx: int,
    text: str,
    font_size: Optional[int] = None,
    font_color: Optional[str] = None,
    bold: Optional[bool] = None,
    italic: Optional[bool] = None,
    align: Optional[str] = None
) -> str:
    """
    プレースホルダーにテキストを設定し、書式も適用する。
    placeholder_idx: list_layouts で確認した idx
    align: "left" / "center" / "right"
    """
    try:
        prs = _load(filepath)
        slide = _get_slide(prs, slide_index)
        ph = None
        for p in slide.placeholders:
            if p.placeholder_format.idx == placeholder_idx:
                ph = p
                break
        if ph is None:
            return f"❌ プレースホルダー idx={placeholder_idx} が見つかりません"
        ph.text = text
        for para in ph.text_frame.paragraphs:
            if align: para.alignment = _align_map(align)
            for run in para.runs:
                _apply_text_style(run, font_size, font_color, bold, italic)
        _save(prs, filepath)
        return f"✅ プレースホルダー（idx={placeholder_idx}）設定完了"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def add_text_box(
    filepath: str,
    slide_index: int,
    text: str,
    left_inches: float,
    top_inches: float,
    width_inches: float,
    height_inches: float,
    font_size: int = 14,
    font_color: str = "#000000",
    bold: bool = False,
    italic: bool = False,
    align: str = "left",
    bg_color: Optional[str] = None,
    font_name: Optional[str] = None,
    wrap_text: bool = True
) -> str:
    """
    テキストボックスを追加する。
    \\n で段落を分割。
    スライドサイズ: 標準16:9は幅13.33インチ×高さ7.5インチ。
    """
    try:
        prs = _load(filepath)
        slide = _get_slide(prs, slide_index)
        txBox = slide.shapes.add_textbox(
            Inches(left_inches), Inches(top_inches),
            Inches(width_inches), Inches(height_inches)
        )
        tf = txBox.text_frame
        tf.word_wrap = wrap_text
        if bg_color:
            txBox.fill.solid()
            txBox.fill.fore_color.rgb = _rgb(bg_color)
        lines = text.split("\n")
        for j, line in enumerate(lines):
            para = tf.paragraphs[0] if j == 0 else tf.add_paragraph()
            para.text = line
            para.alignment = _align_map(align)
            for run in para.runs:
                _apply_text_style(run, font_size, font_color, bold, italic, font_name)
        _save(prs, filepath)
        return f"✅ テキストボックス追加（スライド{slide_index}）"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def set_slide_notes(filepath: str, slide_index: int, notes_text: str) -> str:
    """発表者ノートを設定する。発表スクリプトや補足説明に使う。"""
    try:
        prs = _load(filepath)
        _get_slide(prs, slide_index).notes_slide.notes_text_frame.text = notes_text
        _save(prs, filepath)
        return f"✅ 発表者ノート設定（スライド{slide_index}）"
    except Exception as e:
        return f"❌ {e}"


# ─────────────────────────────────────────────────────────
# ■ 表（テーブル）
# ─────────────────────────────────────────────────────────

@mcp.tool()
def add_table(
    filepath: str,
    slide_index: int,
    data: list[list[str]],
    left_inches: float,
    top_inches: float,
    width_inches: float,
    height_inches: float,
    header_bg_color: str = "#1F4E79",
    header_font_color: str = "#FFFFFF",
    body_font_size: int = 11,
    header_font_size: int = 12,
    alt_row_color: Optional[str] = "#EBF3FF",
    header_bold: bool = True
) -> str:
    """
    表をスライドに追加する。
    data: 2次元リスト（1行目がヘッダー行として扱われる）
    alt_row_color: 偶数行の背景色（省略で白のみ）
    スライドサイズを考慮してwidth_inchesを指定すること（16:9で最大~12インチ）。
    """
    try:
        if not data:
            return "❌ データが空です"
        prs = _load(filepath)
        slide = _get_slide(prs, slide_index)
        rows = len(data)
        cols = max(len(r) for r in data)
        tbl_shape = slide.shapes.add_table(
            rows, cols,
            Inches(left_inches), Inches(top_inches),
            Inches(width_inches), Inches(height_inches)
        )
        tbl = tbl_shape.table
        for r_i, row_data in enumerate(data):
            for c_i in range(cols):
                cell = tbl.cell(r_i, c_i)
                val = row_data[c_i] if c_i < len(row_data) else ""
                tf = cell.text_frame
                tf.clear()
                para = tf.paragraphs[0]
                run = para.add_run()
                run.text = str(val)
                # フォント設定
                is_header = (r_i == 0)
                run.font.size = Pt(header_font_size if is_header else body_font_size)
                run.font.bold = header_bold if is_header else False
                if is_header:
                    run.font.color.rgb = _rgb(header_font_color)
                # 背景色
                fill = cell.fill
                fill.solid()
                if is_header:
                    fill.fore_color.rgb = _rgb(header_bg_color)
                elif alt_row_color and r_i % 2 == 0:
                    fill.fore_color.rgb = _rgb(alt_row_color)
                else:
                    fill.fore_color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        _save(prs, filepath)
        return f"✅ 表追加（スライド{slide_index}）: {rows}行 × {cols}列"
    except Exception as e:
        return f"❌ {e}"


# ─────────────────────────────────────────────────────────
# ■ 図形
# ─────────────────────────────────────────────────────────

@mcp.tool()
def add_shape(
    filepath: str,
    slide_index: int,
    shape_type: str,
    left_inches: float,
    top_inches: float,
    width_inches: float,
    height_inches: float,
    fill_color: Optional[str] = None,
    line_color: Optional[str] = None,
    line_width_pt: float = 1.0,
    text: Optional[str] = None,
    font_size: int = 12,
    font_color: str = "#000000",
    bold: bool = False,
    align: str = "center"
) -> str:
    """
    図形を追加する。
    shape_type: rectangle / rounded_rectangle / oval / diamond / triangle /
                right_arrow / left_arrow / up_arrow / down_arrow /
                chevron / pentagon / hexagon / parallelogram /
                trapezoid / star_4 / star_5 / callout / cloud / cylinder
    fill_color / line_color: "#RRGGBB" 形式（省略で透明/デフォルト）
    """
    try:
        prs = _load(filepath)
        slide = _get_slide(prs, slide_index)
        auto_type = SHAPE_MAP.get(shape_type, 1)
        shape = slide.shapes.add_shape(
            auto_type,
            Inches(left_inches), Inches(top_inches),
            Inches(width_inches), Inches(height_inches)
        )
        if fill_color:
            shape.fill.solid()
            shape.fill.fore_color.rgb = _rgb(fill_color)
        else:
            shape.fill.background()
        if line_color:
            shape.line.color.rgb = _rgb(line_color)
            shape.line.width = Pt(line_width_pt)
        else:
            shape.line.fill.background()
        if text:
            tf = shape.text_frame
            tf.word_wrap = True
            para = tf.paragraphs[0]
            para.alignment = _align_map(align)
            run = para.add_run()
            run.text = text
            _apply_text_style(run, font_size, font_color, bold)
        _save(prs, filepath)
        return f"✅ 図形追加: {shape_type}（スライド{slide_index}）"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def add_connector(
    filepath: str,
    slide_index: int,
    start_x_inches: float,
    start_y_inches: float,
    end_x_inches: float,
    end_y_inches: float,
    line_color: str = "#000000",
    line_width_pt: float = 1.5,
    has_arrow_end: bool = True,
    has_arrow_start: bool = False,
    dash_style: str = "solid"
) -> str:
    """
    コネクタ（直線・矢印）を追加する。フローチャートの接続線として使う。
    dash_style: "solid" / "dash" / "dot" / "dashDot"
    """
    try:
        prs = _load(filepath)
        slide = _get_slide(prs, slide_index)
        connector = slide.shapes.add_connector(
            1,  # MSO_CONNECTOR.STRAIGHT
            Inches(start_x_inches), Inches(start_y_inches),
            Inches(end_x_inches), Inches(end_y_inches)
        )
        ln = connector.line
        ln.color.rgb = _rgb(line_color)
        ln.width = Pt(line_width_pt)
        # 矢印設定（XML直接操作）
        if has_arrow_end or has_arrow_start:
            sp_pr = connector._element.spPr
            ln_elem = sp_pr.find(qn("a:ln"))
            if ln_elem is None:
                ln_elem = etree.SubElement(sp_pr, qn("a:ln"))
            if has_arrow_end:
                tail = etree.SubElement(ln_elem, qn("a:tailEnd"))
                tail.set("type", "arrow")
            if has_arrow_start:
                head = etree.SubElement(ln_elem, qn("a:headEnd"))
                head.set("type", "arrow")
        _save(prs, filepath)
        return f"✅ コネクタ追加（スライド{slide_index}）: ({start_x_inches},{start_y_inches})→({end_x_inches},{end_y_inches})"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def add_image(
    filepath: str,
    slide_index: int,
    image_path: str,
    left_inches: float,
    top_inches: float,
    width_inches: Optional[float] = None,
    height_inches: Optional[float] = None
) -> str:
    """
    画像をスライドに挿入する。
    width / height のどちらか一方を省略するとアスペクト比を維持する。
    """
    try:
        if not Path(image_path).exists():
            return f"❌ 画像が見つかりません: {image_path}"
        prs = _load(filepath)
        slide = _get_slide(prs, slide_index)
        kwargs = {"left": Inches(left_inches), "top": Inches(top_inches)}
        if width_inches: kwargs["width"] = Inches(width_inches)
        if height_inches: kwargs["height"] = Inches(height_inches)
        slide.shapes.add_picture(image_path, **kwargs)
        _save(prs, filepath)
        return f"✅ 画像挿入（スライド{slide_index}）: {image_path}"
    except Exception as e:
        return f"❌ {e}"


# ─────────────────────────────────────────────────────────
# エントリポイント
# ─────────────────────────────────────────────────────────
if __name__ == "__main__":
    _log("PowerPoint MCP Server v2.0 起動中...")
    mcp.run(transport="stdio")
```

---

## 5. IDE設定（VS Code / Kiro）

### VS Code `.vscode/mcp.json`（Excel + PowerPoint 両方）

```json
{
  "servers": {
    "excel-mcp": {
      "type": "stdio",
      "command": "python",
      "args": ["${workspaceFolder}/mcp_servers/excel/excel_mcp_server.py"]
    },
    "pptx-mcp": {
      "type": "stdio",
      "command": "python",
      "args": ["${workspaceFolder}/mcp_servers/pptx/pptx_mcp_server.py"]
    }
  }
}
```

### Kiro `.kiro/settings/mcp.json`（Excel + PowerPoint 両方）

```json
{
  "mcpServers": {
    "excel-mcp": {
      "command": "python",
      "args": ["${workspaceFolder}/mcp_servers/excel/excel_mcp_server.py"],
      "disabled": false,
      "autoApprove": ["create_workbook","copy_template_to_output","list_template_files",
        "add_sheet","copy_sheet","set_sheet_tab_color","get_workbook_info","list_sheets",
        "write_data","write_cell","read_sheet","read_cell","inspect_sheet",
        "find_cell_by_value","replace_cell_value","clear_range","apply_style_range",
        "set_column_widths","auto_fit_columns","set_row_height","merge_cells",
        "freeze_panes","set_number_format","add_hyperlink","add_excel_table",
        "add_auto_filter","add_dropdown_validation","add_color_scale","add_data_bar",
        "add_conditional_format_rule","add_bar_chart","add_line_chart","add_pie_chart",
        "set_print_settings"]
    },
    "pptx-mcp": {
      "command": "python",
      "args": ["${workspaceFolder}/mcp_servers/pptx/pptx_mcp_server.py"],
      "disabled": false,
      "autoApprove": ["create_presentation","list_templates","list_layouts",
        "get_presentation_info","read_all_slides_text","add_slide","duplicate_slide",
        "set_slide_background","set_placeholder_text","add_text_box","set_slide_notes",
        "add_table","add_shape","add_connector","add_image"]
    }
  }
}
```

---

## 6. ツール完全一覧

### プレゼンテーション基本

| ツール | 説明 |
|--------|------|
| `create_presentation` | 社内テンプレートから作成（テーマ継承） |
| `list_templates` | 利用可能テンプレート一覧 |
| `list_layouts` | **最初に実行**・使えるレイアウト確認 |
| `get_presentation_info` | スライド数・サイズ・タイトル一覧 |
| `read_all_slides_text` | 全スライドのテキスト一括取得 |

### スライド操作

| ツール | 説明 |
|--------|------|
| `add_slide` | スライド追加（タイトル・本文・ノート一括設定） |
| `duplicate_slide` | スライド複製（テンプレートスライドの流用） |
| `set_slide_background` | 背景色設定 |

### テキスト

| ツール | 説明 |
|--------|------|
| `set_placeholder_text` | プレースホルダーへのテキスト設定・書式適用 |
| `add_text_box` | テキストボックス追加（自由配置） |
| `set_slide_notes` | 発表者ノート設定（発表スクリプト） |

### 表・図形

| ツール | 説明 |
|--------|------|
| `add_table` | 表追加（ヘッダー色・交互行色・フォント一括設定） |
| `add_shape` | 図形追加（17種類対応） |
| `add_connector` | コネクタ（直線・矢印）追加 |
| `add_image` | 画像挿入 |

---

## 7. 社内テンプレートの調査と活用

### 調査手順

```
1. list_layouts → レイアウト一覧取得
2. 各レイアウトのプレースホルダー idx を確認
3. Steering に記録してAIに常時参照させる
```

### よくあるレイアウト構成例

```json
[
  {"index": 0, "name": "タイトル スライド",
   "placeholders": [{"idx": 0, "type": "CENTER_TITLE"}, {"idx": 1, "type": "SUBTITLE"}]},
  {"index": 1, "name": "タイトルとコンテンツ",
   "placeholders": [{"idx": 0, "type": "TITLE"}, {"idx": 1, "type": "BODY"}]},
  {"index": 2, "name": "セクション ヘッダー",
   "placeholders": [{"idx": 0, "type": "CENTER_TITLE"}, {"idx": 1, "type": "SUBTITLE"}]},
  {"index": 5, "name": "タイトルのみ",
   "placeholders": [{"idx": 0, "type": "TITLE"}]}
]
```

---

## 8. ワークフロー詳細とプロンプト例

### RCA報告書スライド

```
社内テンプレートから output/rca_wifi_20260402.pptx を作成してください。

手順：
1. list_layouts でレイアウト確認
2. create_presentation でテンプレートから作成
3. 以下の構成でスライドを追加：

スライド1（表紙 layout=0）
  タイトル: Wi-Fi障害 根本原因分析
  サブタイトル: 2026/03/28 ネットワークチーム

スライド2（タイトルとコンテンツ layout=1）
  タイトル: 障害概要
  本文（箇条書き）:
  発生日時: 2026/03/28 09:15 JST
  解決日時: 2026/03/28 14:30 JST
  影響範囲: 東京オフィス全フロア（約200名）
  根本原因: Cisco ISE → Intune → Firewall 連鎖障害

スライド3（タイトルとコンテンツ layout=1）
  タイトル: 根本原因分析（5WHY）
  テーブルで追加: Why1〜Why5 / 各層の原因を記載

スライド4（タイトルのみ layout=5）
  タイトル: 再発防止策
  テーブル追加（left=0.5, top=1.5, width=12, height=4）:
  対策 / 担当 / 期限 / 状況
  ISE証明書自動更新設定 / NWチーム / 4/15 / 対応中
  Intune MDM除外ルール整備 / クライアントチーム / 4/20 / 未着手

各スライドに発表者ノート（発表スクリプト）も追加。
```

### 仕様駆動開発の設計説明資料

```
spec.md とSteering情報を読んで、
output/design_review_ec2_20260402.pptx を作成してください。

構成：
1. 表紙（システム名・日付・担当者）
2. アーキテクチャ概要（テキストボックスでAWS構成を説明）
3. EC2設計パラメータ（テーブル形式）
4. セキュリティグループ設計（テーブル: インバウンド/アウトバウンドルール）
5. 課題・確認事項（箇条書き）
6. 次のアクション（担当・期限付きテーブル）

全体を社内テンプレートのフォーマットで作成。
```

---

## 9. Kiro Steering連携

**`.kiro/steering/pptx-workflow-guide.md`**

```markdown
---
inclusion: auto
fileMatch: ["*.pptx", "output/**", "**/rca*", "**/review*", "**/design*"]
---

# PowerPoint MCP 作業ガイド

## テンプレートパス
mcp_servers/pptx/templates/company_template.pptx

## 作業の必須手順
1. list_layouts で利用可能なレイアウトを確認
2. create_presentation でテンプレートから作成
3. add_slide でスライドを追加（layout_index を必ず指定）
4. 各スライドに set_slide_notes で発表者ノートを追加

## スライドレイアウト（社内テンプレート）
- 0: タイトルスライド（表紙）
- 1: タイトルとコンテンツ（本文スライド）
- 2: セクションヘッダー（章区切り）
- 5: タイトルのみ（表・図挿入用）

## スライドサイズ（16:9 ワイドスクリーン）
- 幅: 13.33インチ
- 高さ: 7.5インチ
- テーブル推奨幅: 最大12インチ（left=0.5 起点）

## カラーパレット（社内標準）
- メインカラー: #1F4E79（ネイビー）
- アクセント: #2E75B6（ブルー）
- テキスト白: #FFFFFF
- テーブルヘッダー背景: #1F4E79 / フォント: #FFFFFF
- テーブル交互行: #EBF3FF

## よく使う図形
- フローチャート: rectangle → add_connector で矢印接続
- 強調ボックス: rounded_rectangle + fill_color
- セクション区切り: pentagon / chevron
```

---

*最終版 v2.0 | 作成日: 2026年4月 | Python 3.10+ / python-pptx 0.6.21+ / mcp 1.0+*
