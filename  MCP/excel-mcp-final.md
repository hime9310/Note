# Excel MCP Server 最終版 完全ガイド

> ローカルstdio型 / 外部通信ゼロ / Claudeと同等のExcel作成能力

---

## 目次

1. [アーキテクチャと通信の仕組み](#1-アーキテクチャと通信の仕組み)
2. [前提条件・制約・審査ポイント](#2-前提条件制約審査ポイント)
3. [環境構築とディレクトリ構成](#3-環境構築とディレクトリ構成)
4. [Pythonコード全文（完全版）](#4-pythonコード全文完全版)
5. [IDE設定（VS Code / Kiro）](#5-ide設定vs-code--kiro)
6. [ツール完全一覧](#6-ツール完全一覧)
7. [2つのワークフロー詳細](#7-2つのワークフロー詳細)
8. [Kiro Steering連携](#8-kiro-steering連携)

---

## 1. アーキテクチャと通信の仕組み

```
【開発者PC：完全ローカル動作・外部通信ゼロ】

 VS Code（Copilot）               Kiro
 or                               ↕ stdin/stdout
 ↕ stdin/stdout            excel_mcp_server.py（子プロセス）
 excel_mcp_server.py                ↓ ファイル操作
        ↓                      .xlsx（ローカル）
   .xlsx（ローカル）

通信方式：IDEが python excel_mcp_server.py を子プロセスとして起動し
          JSON-RPC メッセージを stdin/stdout で交換するのみ。
          ネットワークポート不使用・外部API不使用。
```

**stdioプロトコルのメッセージ例：**

```json
// IDEからMCPサーバーへ（stdin）
{"jsonrpc":"2.0","id":1,"method":"tools/call",
 "params":{"name":"create_workbook","arguments":{"filepath":"C:/work/spec.xlsx"}}}

// MCPサーバーからIDEへ（stdout）
{"jsonrpc":"2.0","id":1,"result":
 {"content":[{"type":"text","text":"✅ ワークブック作成完了"}]}}
```

> **重要：** `stdout`はプロトコル専用。デバッグログは必ず`stderr`へ。

---

## 2. 前提条件・制約・審査ポイント

### 必要なソフトウェア

| # | ソフトウェア | 種別 | 外部通信 |
|---|------------|------|--------|
| 1 | Python 3.10以上 | インタープリタ | **なし** |
| 2 | `mcp` (pip) | MCP SDK | **なし**（stdio通信のみ） |
| 3 | `openpyxl` (pip) | Excel操作 | **なし** |

```powershell
# インストール確認
python --version   # 3.10.x 以上

# インストール（プロキシ環境）
pip install mcp openpyxl --proxy http://your-proxy:port

# 管理者権限なし
pip install mcp openpyxl --user
```

### openpyxlで対応できる機能 vs 制約

| 機能 | 対応 |
|------|------|
| セル読み書き・数式 | ✅ |
| 書式（色・フォント・罫線・数値形式） | ✅ |
| セル結合・列幅・行高さ | ✅ |
| ペイン固定・オートフィルター | ✅ |
| Excelテーブル（テーブルスタイル付き） | ✅ |
| ドロップダウン（入力規則） | ✅ |
| 条件付き書式（カラースケール・ルール） | ✅ |
| チャート（棒・折れ線・円・積み上げ） | ✅ |
| ハイパーリンク | ✅ |
| 印刷設定（印刷範囲・用紙） | ✅ |
| シートタブ色・コピー | ✅ |
| **グラフ内の高度なスタイリング** | ⚠️ 限定的 |
| **ピボットテーブル生成** | ❌ |
| **VBAマクロ（.xlsm）** | ❌ |
| **スパークライン** | ❌ |

### 審査チェックリスト

```
□ 外部API通信       → なし（プロセス間stdin/stdout通信のみ）
□ クラウド接続       → なし（完全ローカル実行）
□ データ外部送信     → なし（ファイルはローカル保存のみ）
□ 認証情報の取り扱い → なし
□ 常駐プロセス       → なし（IDE起動中のみ子プロセスとして動作）
□ ネットワークポート → 不使用（stdio型）
□ 管理者権限        → 不要（--userインストール対応）
□ インターネット接続 → 不要（pip installは事前に完結）
```

---

## 3. 環境構築とディレクトリ構成

```
project/
├── .kiro/
│   ├── settings/
│   │   └── mcp.json                    ← Kiro MCP設定
│   └── steering/
│       └── excel-workflow-guide.md     ← AI常時参照ガイド
├── .vscode/
│   └── mcp.json                        ← VS Code MCP設定
├── mcp_servers/
│   └── excel/
│       ├── excel_mcp_server.py         ← MCPサーバー本体
│       ├── requirements.txt
│       └── templates/                  ← 社内テンプレート置き場
│           ├── parameter_sheet.xlsx
│           ├── unit_test_spec.xlsx
│           └── design_review.xlsx
└── output/                             ← 生成ファイル出力先
```

**requirements.txt**
```
mcp>=1.0.0
openpyxl>=3.1.0
```

---

## 4. Pythonコード全文（完全版）

**`mcp_servers/excel/excel_mcp_server.py`**

```python
"""
Excel MCP Server - 最終版
Claudeと同等のExcel作成・編集能力 / ローカルstdio型 / 外部通信ゼロ
"""

import sys
import json
import shutil
from pathlib import Path
from typing import Optional, Any

import openpyxl
from openpyxl.styles import PatternFill, Font, Alignment, Border, Side
from openpyxl.utils import get_column_letter, column_index_from_string
from openpyxl.worksheet.table import Table, TableStyleInfo
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.formatting.rule import (
    ColorScaleRule, DataBarRule, CellIsRule, FormulaRule
)
from openpyxl.chart import BarChart, LineChart, PieChart, Reference
from openpyxl.chart.series import DataPoint

from mcp.server.fastmcp import FastMCP

# ─────────────────────────────────────────────────────────
# 初期化
# ─────────────────────────────────────────────────────────
mcp = FastMCP(name="excel-mcp-server", version="2.0.0")

def _log(msg: str):
    print(f"[excel-mcp] {msg}", file=sys.stderr)

def _load(filepath: str) -> openpyxl.Workbook:
    p = Path(filepath)
    if not p.exists():
        raise FileNotFoundError(f"ファイルが見つかりません: {filepath}")
    return openpyxl.load_workbook(filepath)

def _save(wb: openpyxl.Workbook, filepath: str):
    Path(filepath).parent.mkdir(parents=True, exist_ok=True)
    wb.save(filepath)
    _log(f"保存: {filepath}")

def _rgb(hex_color: str) -> str:
    """#RRGGBB → RRGGBB（openpyxl用）"""
    return hex_color.lstrip("#").upper()

def _side(style="thin", color="000000"):
    return Side(style=style, color=color)

def _border(style="thin", color="000000"):
    s = _side(style, color)
    return Border(left=s, right=s, top=s, bottom=s)

def _col(col) -> int:
    """列名 or 列番号 → 列番号"""
    return column_index_from_string(col) if isinstance(col, str) else col


# ─────────────────────────────────────────────────────────
# ■ ワークブック操作
# ─────────────────────────────────────────────────────────

@mcp.tool()
def create_workbook(
    filepath: str,
    sheet_names: list[str] = ["Sheet1"]
) -> str:
    """
    新しいExcelワークブックを作成する。
    filepath: 保存先（例: C:/work/output/spec.xlsx）
    sheet_names: 作成するシート名リスト（先頭がアクティブシートになる）
    """
    try:
        wb = openpyxl.Workbook()
        wb.active.title = sheet_names[0]
        for name in sheet_names[1:]:
            wb.create_sheet(title=name)
        _save(wb, filepath)
        return f"✅ ワークブック作成: {filepath} / シート: {', '.join(sheet_names)}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def copy_template_to_output(
    template_filepath: str,
    output_filepath: str,
    overwrite: bool = False
) -> str:
    """
    テンプレートを出力先にコピーする。テンプレートベース作業では必ず最初に実行する。
    原本テンプレートを直接編集しないための保護手順。
    overwrite=True で既存ファイルを上書き。
    """
    try:
        src = Path(template_filepath)
        dst = Path(output_filepath)
        if not src.exists():
            return f"❌ テンプレートが見つかりません: {template_filepath}"
        if dst.exists() and not overwrite:
            return f"⚠️ 出力先にファイルが存在します: {output_filepath}（上書きするには overwrite=True）"
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(str(src), str(dst))
        return f"✅ テンプレートをコピー: {template_filepath} → {output_filepath}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def list_template_files(template_dir: str) -> str:
    """テンプレートフォルダ内のExcelファイル一覧を取得する。"""
    try:
        p = Path(template_dir)
        if not p.exists():
            return f"❌ フォルダが存在しません: {template_dir}"
        files = [{"name": f.name, "path": str(f), "size_kb": round(f.stat().st_size / 1024, 1)}
                 for f in sorted(p.glob("*.xlsx"))]
        return json.dumps(files, ensure_ascii=False, indent=2) if files else "Excelファイルなし"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def add_sheet(
    filepath: str,
    sheet_name: str,
    position: Optional[int] = None
) -> str:
    """既存ワークブックにシートを追加する。position省略時は末尾に追加。"""
    try:
        wb = _load(filepath)
        wb.create_sheet(title=sheet_name, index=position)
        _save(wb, filepath)
        return f"✅ シート追加: {sheet_name}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def copy_sheet(filepath: str, source_sheet: str, new_sheet_name: str) -> str:
    """シートをコピーする（テンプレートシートの複製に使用）。"""
    try:
        wb = _load(filepath)
        wb.copy_worksheet(wb[source_sheet]).title = new_sheet_name
        _save(wb, filepath)
        return f"✅ シートコピー: {source_sheet} → {new_sheet_name}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def set_sheet_tab_color(filepath: str, sheet_name: str, color: str) -> str:
    """
    シートタブの色を設定する。
    color: 例 "#FF0000"（赤）、"#1F4E79"（ネイビー）
    """
    try:
        wb = _load(filepath)
        wb[sheet_name].sheet_properties.tabColor = _rgb(color)
        _save(wb, filepath)
        return f"✅ タブ色設定: {sheet_name} → {color}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def get_workbook_info(filepath: str) -> str:
    """ワークブックの概要（シート名・各シートの行列数）を取得する。"""
    try:
        wb = _load(filepath)
        info = {"filepath": filepath, "sheets": []}
        for name in wb.sheetnames:
            ws = wb[name]
            info["sheets"].append({
                "name": name,
                "max_row": ws.max_row,
                "max_col": ws.max_column,
                "max_col_letter": get_column_letter(ws.max_column) if ws.max_column else "A"
            })
        return json.dumps(info, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def list_sheets(filepath: str) -> str:
    """ワークブックのシート名一覧を取得する。"""
    try:
        wb = _load(filepath)
        return json.dumps(wb.sheetnames, ensure_ascii=False)
    except Exception as e:
        return f"❌ {e}"


# ─────────────────────────────────────────────────────────
# ■ データ読み書き
# ─────────────────────────────────────────────────────────

@mcp.tool()
def write_data(
    filepath: str,
    sheet_name: str,
    data: list[list[Any]],
    start_row: int = 1,
    start_col: int = 1
) -> str:
    """
    2次元配列のデータをシートに書き込む。
    data: [["ヘッダー1","ヘッダー2"],[値1,値2],...] の形式
    start_row / start_col: 書き込み開始位置（1始まり）
    数式は文字列で "=SUM(B2:B10)" のように指定する。
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        for r_i, row in enumerate(data):
            for c_i, val in enumerate(row):
                ws.cell(row=start_row + r_i, column=start_col + c_i, value=val)
        _save(wb, filepath)
        rows = len(data)
        cols = max(len(r) for r in data) if data else 0
        return f"✅ データ書き込み完了: {rows}行 × {cols}列"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def write_cell(
    filepath: str,
    sheet_name: str,
    row: int,
    col: Any,
    value: Any
) -> str:
    """
    単一セルに値または数式を書き込む。
    col: 列番号（1=A）または列名（"A","B"...）
    value: 値または数式文字列（例: "=SUM(B2:B10)"）
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        c = _col(col)
        ws.cell(row=row, column=c, value=value)
        _save(wb, filepath)
        return f"✅ {get_column_letter(c)}{row} = {value}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def read_sheet(
    filepath: str,
    sheet_name: str,
    max_rows: int = 200,
    max_cols: int = 50
) -> str:
    """シートのデータをJSON形式で読み込む。"""
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        result = []
        for row in ws.iter_rows(
            max_row=min(ws.max_row or 1, max_rows),
            max_col=min(ws.max_column or 1, max_cols),
            values_only=True
        ):
            result.append(list(row))
        return json.dumps(result, ensure_ascii=False, default=str)
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def read_cell(filepath: str, sheet_name: str, row: int, col: Any) -> str:
    """単一セルの値と情報を取得する。"""
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        c = _col(col)
        cell = ws.cell(row=row, column=c)
        is_merged = any(cell.coordinate in m for m in ws.merged_cells.ranges)
        return json.dumps({
            "cell": f"{get_column_letter(c)}{row}",
            "value": cell.value,
            "number_format": cell.number_format,
            "is_merged": is_merged
        }, ensure_ascii=False, default=str)
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def inspect_sheet(
    filepath: str,
    sheet_name: str,
    max_rows: int = 60,
    max_cols: int = 20
) -> str:
    """
    シートの構造を詳細に把握する。
    どのセルに何が入っているか、結合セル、最大行列を返す。
    テンプレートの記入箇所を探す際に使用する。
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        cells_data = []
        for row in ws.iter_rows(
            max_row=min(ws.max_row or 1, max_rows),
            max_col=min(ws.max_column or 1, max_cols)
        ):
            for cell in row:
                if cell.value is not None:
                    cells_data.append({
                        "cell": f"{get_column_letter(cell.column)}{cell.row}",
                        "row": cell.row,
                        "col": cell.column,
                        "value": str(cell.value)
                    })
        return json.dumps({
            "sheet": sheet_name,
            "max_row": ws.max_row,
            "max_col": ws.max_column,
            "merged_cells": [str(m) for m in ws.merged_cells.ranges],
            "cells_with_data": cells_data
        }, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def find_cell_by_value(
    filepath: str,
    sheet_name: str,
    search_text: str,
    partial_match: bool = True
) -> str:
    """
    シート内で特定テキストを含むセルを検索する。
    テンプレートの記入箇所（★, TBD, TODO 等）を探すのに使う。
    partial_match=True で部分一致。
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        found = []
        for row in ws.iter_rows():
            for cell in row:
                if cell.value is None:
                    continue
                s = str(cell.value)
                hit = search_text.lower() in s.lower() if partial_match else s == search_text
                if hit:
                    found.append({
                        "cell": f"{get_column_letter(cell.column)}{cell.row}",
                        "row": cell.row, "col": cell.column, "value": s
                    })
        return json.dumps(found, ensure_ascii=False, indent=2) if found else f'"{search_text}" は見つかりませんでした'
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def replace_cell_value(
    filepath: str,
    sheet_name: str,
    search_text: str,
    replace_value: Any,
    replace_all: bool = True
) -> str:
    """
    シート内の特定テキストを新しい値に置換する。
    テンプレートの「★入力」「TBD」等を実際の値に置き換える際に使う。
    replace_all=False の場合、最初の1つのみ置換。
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        count = 0
        for row in ws.iter_rows():
            for cell in row:
                if cell.value is not None and str(cell.value) == search_text:
                    cell.value = replace_value
                    count += 1
                    if not replace_all:
                        _save(wb, filepath)
                        return f"✅ 1箇所置換: '{search_text}' → '{replace_value}'"
        _save(wb, filepath)
        return f"✅ {count}箇所置換: '{search_text}' → '{replace_value}'"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def clear_range(
    filepath: str,
    sheet_name: str,
    start_row: int,
    start_col: int,
    end_row: int,
    end_col: int
) -> str:
    """
    セル範囲の値のみクリアする（書式・色・罫線は維持）。
    テンプレートのサンプルデータを消して新しいデータを入れる前に使う。
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        count = 0
        for r in range(start_row, end_row + 1):
            for c in range(start_col, end_col + 1):
                ws.cell(row=r, column=c).value = None
                count += 1
        _save(wb, filepath)
        return f"✅ {count}セルをクリア（書式維持）: {get_column_letter(start_col)}{start_row}:{get_column_letter(end_col)}{end_row}"
    except Exception as e:
        return f"❌ {e}"


# ─────────────────────────────────────────────────────────
# ■ 書式設定
# ─────────────────────────────────────────────────────────

@mcp.tool()
def apply_style_range(
    filepath: str,
    sheet_name: str,
    start_row: int,
    start_col: int,
    end_row: int,
    end_col: int,
    bg_color: Optional[str] = None,
    font_color: Optional[str] = None,
    bold: bool = False,
    font_size: Optional[int] = None,
    font_name: Optional[str] = None,
    horizontal_align: Optional[str] = None,
    vertical_align: Optional[str] = None,
    wrap_text: bool = False,
    border: bool = False,
    border_style: str = "thin",
    border_color: str = "000000"
) -> str:
    """
    セル範囲にスタイルを一括適用する。
    bg_color / font_color: "#1F4E79" 形式のHEXカラー
    horizontal_align: "left" / "center" / "right"
    vertical_align: "top" / "center" / "bottom"
    border_style: "thin" / "medium" / "thick" / "double" / "dashed"
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        fill = PatternFill(fill_type="solid", fgColor=_rgb(bg_color)) if bg_color else None
        font_kw: dict = {}
        if bold: font_kw["bold"] = True
        if font_color: font_kw["color"] = _rgb(font_color)
        if font_size: font_kw["size"] = font_size
        if font_name: font_kw["name"] = font_name
        font = Font(**font_kw) if font_kw else None
        align_kw: dict = {}
        if horizontal_align: align_kw["horizontal"] = horizontal_align
        if vertical_align: align_kw["vertical"] = vertical_align
        if wrap_text: align_kw["wrap_text"] = True
        alignment = Alignment(**align_kw) if align_kw else None
        border_obj = _border(border_style, border_color) if border else None
        for r in range(start_row, end_row + 1):
            for c in range(start_col, end_col + 1):
                cell = ws.cell(row=r, column=c)
                if fill: cell.fill = fill
                if font: cell.font = font
                if alignment: cell.alignment = alignment
                if border_obj: cell.border = border_obj
        _save(wb, filepath)
        return f"✅ スタイル適用: {get_column_letter(start_col)}{start_row}:{get_column_letter(end_col)}{end_row}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def set_column_widths(filepath: str, sheet_name: str, widths: dict) -> str:
    """
    列幅を設定する。
    widths: {"A": 20, "B": 15} のように列名→幅（文字数単位）で指定。
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        for col_letter, width in widths.items():
            ws.column_dimensions[col_letter.upper()].width = width
        _save(wb, filepath)
        return f"✅ 列幅設定: {widths}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def auto_fit_columns(filepath: str, sheet_name: str, padding: int = 2) -> str:
    """
    全列の幅をコンテンツに合わせて自動調整する。
    日本語は2文字分の幅として計算する。padding で余白を追加（デフォルト2文字）。
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        for col in ws.columns:
            max_len = 0
            col_letter = get_column_letter(col[0].column)
            for cell in col:
                if cell.value:
                    length = sum(2 if ord(c) > 127 else 1 for c in str(cell.value))
                    max_len = max(max_len, length)
            ws.column_dimensions[col_letter].width = max_len + padding
        _save(wb, filepath)
        return "✅ 列幅自動調整完了"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def set_row_height(filepath: str, sheet_name: str, row: int, height: float) -> str:
    """行の高さを設定する。height はポイント単位（標準15）。"""
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        ws.row_dimensions[row].height = height
        _save(wb, filepath)
        return f"✅ 行高さ設定: {row}行目 → {height}pt"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def merge_cells(
    filepath: str,
    sheet_name: str,
    start_row: int,
    start_col: int,
    end_row: int,
    end_col: int
) -> str:
    """
    セルを結合する。
    ※ 結合前に start_row/start_col のセルに値を書き込んでおくこと。
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        ws.merge_cells(
            start_row=start_row, start_column=start_col,
            end_row=end_row, end_column=end_col
        )
        _save(wb, filepath)
        sc = get_column_letter(start_col)
        ec = get_column_letter(end_col)
        return f"✅ セル結合: {sc}{start_row}:{ec}{end_row}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def freeze_panes(
    filepath: str,
    sheet_name: str,
    freeze_row: int = 1,
    freeze_col: int = 0
) -> str:
    """
    ペインを固定する。
    freeze_row=1 → 1行目を固定（ヘッダー固定の標準設定）
    freeze_col=0 → 列は固定なし
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        col_letter = get_column_letter(freeze_col + 1) if freeze_col > 0 else "A"
        ws.freeze_panes = f"{col_letter}{freeze_row + 1}"
        _save(wb, filepath)
        return f"✅ ペイン固定: {freeze_row}行/{freeze_col}列"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def set_number_format(
    filepath: str,
    sheet_name: str,
    start_row: int,
    start_col: int,
    end_row: int,
    end_col: int,
    format_code: str
) -> str:
    """
    セル範囲に数値フォーマットを設定する。
    format_code 例：
      "#,##0"        → 整数カンマ区切り
      "#,##0.00"     → 小数2桁
      "0%"           → パーセント
      "0.0%"         → パーセント小数1桁
      "yyyy/mm/dd"   → 日付
      "@"            → 文字列
      "¥#,##0"       → 円
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        for r in range(start_row, end_row + 1):
            for c in range(start_col, end_col + 1):
                ws.cell(row=r, column=c).number_format = format_code
        _save(wb, filepath)
        return f"✅ 数値フォーマット設定: {format_code}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def add_hyperlink(
    filepath: str,
    sheet_name: str,
    row: int,
    col: Any,
    url: str,
    display_text: Optional[str] = None
) -> str:
    """
    セルにハイパーリンクを設定する。
    url: "https://..." または "#SheetName!A1"（シート内リンク）
    display_text: 表示テキスト（省略時はURLをそのまま表示）
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        c = _col(col)
        cell = ws.cell(row=row, column=c)
        cell.hyperlink = url
        cell.value = display_text or url
        cell.font = Font(color="0563C1", underline="single")
        _save(wb, filepath)
        return f"✅ ハイパーリンク設定: {get_column_letter(c)}{row} → {url}"
    except Exception as e:
        return f"❌ {e}"


# ─────────────────────────────────────────────────────────
# ■ テーブル・フィルター
# ─────────────────────────────────────────────────────────

@mcp.tool()
def add_excel_table(
    filepath: str,
    sheet_name: str,
    table_name: str,
    start_row: int,
    start_col: int,
    end_row: int,
    end_col: int,
    table_style: str = "TableStyleMedium9"
) -> str:
    """
    Excelテーブル（ListObject）を追加する。
    オートフィルターとテーブルスタイルが自動的に付与される。
    1行目がヘッダーとして扱われる。

    table_name: 英数字とアンダースコアのみ（日本語不可）
    table_style: "TableStyleLight1"〜"TableStyleDark11"
                 例: Light=薄色, Medium=中間色, Dark=濃色
                 数字はバリエーション（1-21 or 1-11）
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        sc = get_column_letter(start_col)
        ec = get_column_letter(end_col)
        ref = f"{sc}{start_row}:{ec}{end_row}"
        tbl = Table(displayName=table_name, ref=ref)
        tbl.tableStyleInfo = TableStyleInfo(
            name=table_style,
            showFirstColumn=False,
            showLastColumn=False,
            showRowStripes=True,
            showColumnStripes=False
        )
        ws.add_table(tbl)
        _save(wb, filepath)
        return f"✅ Excelテーブル作成: {table_name}（{ref}）スタイル: {table_style}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def add_auto_filter(
    filepath: str,
    sheet_name: str,
    start_row: int,
    start_col: int,
    end_row: int,
    end_col: int
) -> str:
    """
    オートフィルター（絞り込みドロップダウン）を設定する。
    Excelテーブルを使わずにフィルターだけ付けたい場合に使う。
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        sc = get_column_letter(start_col)
        ec = get_column_letter(end_col)
        ws.auto_filter.ref = f"{sc}{start_row}:{ec}{end_row}"
        _save(wb, filepath)
        return f"✅ オートフィルター設定: {sc}{start_row}:{ec}{end_row}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def add_dropdown_validation(
    filepath: str,
    sheet_name: str,
    start_row: int,
    start_col: int,
    end_row: int,
    end_col: int,
    options: list[str],
    error_message: str = "リストから選択してください"
) -> str:
    """
    ドロップダウンリスト（入力規則）を設定する。
    options: 選択肢リスト（例: ["高", "中", "低"]）
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        formula = '"' + ",".join(options) + '"'
        dv = DataValidation(type="list", formula1=formula, allow_blank=True, showDropDown=False)
        dv.error = error_message
        dv.errorTitle = "入力エラー"
        sc = get_column_letter(start_col)
        ec = get_column_letter(end_col)
        dv.sqref = f"{sc}{start_row}:{ec}{end_row}"
        ws.add_data_validation(dv)
        _save(wb, filepath)
        return f"✅ ドロップダウン設定: {options}"
    except Exception as e:
        return f"❌ {e}"


# ─────────────────────────────────────────────────────────
# ■ 条件付き書式
# ─────────────────────────────────────────────────────────

@mcp.tool()
def add_color_scale(
    filepath: str,
    sheet_name: str,
    start_row: int,
    start_col: int,
    end_row: int,
    end_col: int,
    min_color: str = "#F8696B",
    mid_color: Optional[str] = "#FFEB84",
    max_color: str = "#63BE7B"
) -> str:
    """
    カラースケール（ヒートマップ的な条件付き書式）を設定する。
    デフォルト: 低=赤 / 中=黄 / 高=緑（Excelの標準カラースケールと同じ）
    mid_color を省略すると2色スケールになる。
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        sc = get_column_letter(start_col)
        ec = get_column_letter(end_col)
        cell_range = f"{sc}{start_row}:{ec}{end_row}"
        if mid_color:
            rule = ColorScaleRule(
                start_type="min", start_color=_rgb(min_color),
                mid_type="percentile", mid_value=50, mid_color=_rgb(mid_color),
                end_type="max", end_color=_rgb(max_color)
            )
        else:
            rule = ColorScaleRule(
                start_type="min", start_color=_rgb(min_color),
                end_type="max", end_color=_rgb(max_color)
            )
        ws.conditional_formatting.add(cell_range, rule)
        _save(wb, filepath)
        return f"✅ カラースケール設定: {cell_range}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def add_data_bar(
    filepath: str,
    sheet_name: str,
    start_row: int,
    start_col: int,
    end_row: int,
    end_col: int,
    color: str = "#638EC6"
) -> str:
    """
    データバー（棒グラフ的な条件付き書式）を設定する。
    color: バーの色（デフォルト: 青系）
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        sc = get_column_letter(start_col)
        ec = get_column_letter(end_col)
        cell_range = f"{sc}{start_row}:{ec}{end_row}"
        rule = DataBarRule(start_type="min", end_type="max", color=_rgb(color))
        ws.conditional_formatting.add(cell_range, rule)
        _save(wb, filepath)
        return f"✅ データバー設定: {cell_range} / 色: {color}"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def add_conditional_format_rule(
    filepath: str,
    sheet_name: str,
    start_row: int,
    start_col: int,
    end_row: int,
    end_col: int,
    operator: str,
    value: Any,
    bg_color: Optional[str] = None,
    font_color: Optional[str] = None,
    bold: bool = False
) -> str:
    """
    条件に一致するセルに書式を適用する。
    operator: "greaterThan" / "lessThan" / "equal" / "notEqual"
              / "greaterThanOrEqual" / "lessThanOrEqual" / "between"
    value: 比較値（"between" の場合は [下限, 上限] のリスト）
    bg_color / font_color: "#FF0000" 形式のHEXカラー
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        sc = get_column_letter(start_col)
        ec = get_column_letter(end_col)
        cell_range = f"{sc}{start_row}:{ec}{end_row}"
        font_kw: dict = {}
        if font_color: font_kw["color"] = _rgb(font_color)
        if bold: font_kw["bold"] = True
        fill = PatternFill(fill_type="solid", fgColor=_rgb(bg_color)) if bg_color else None
        font = Font(**font_kw) if font_kw else None
        if isinstance(value, list) and len(value) == 2:
            rule = CellIsRule(operator=operator, formula=[str(value[0]), str(value[1])],
                              fill=fill, font=font)
        else:
            rule = CellIsRule(operator=operator, formula=[str(value)],
                              fill=fill, font=font)
        ws.conditional_formatting.add(cell_range, rule)
        _save(wb, filepath)
        return f"✅ 条件付き書式設定: {cell_range} / {operator} {value}"
    except Exception as e:
        return f"❌ {e}"


# ─────────────────────────────────────────────────────────
# ■ チャート
# ─────────────────────────────────────────────────────────

@mcp.tool()
def add_bar_chart(
    filepath: str,
    sheet_name: str,
    data_start_row: int,
    data_start_col: int,
    data_end_row: int,
    data_end_col: int,
    chart_anchor_cell: str,
    title: str = "",
    chart_type: str = "bar",
    width_cm: float = 15,
    height_cm: float = 10,
    has_header_row: bool = True,
    has_categories_col: bool = True
) -> str:
    """
    棒グラフをシートに追加する。
    data_start/end: データ範囲（ヘッダー行・カテゴリ列を含む）
    chart_anchor_cell: グラフの左上角のセル（例: "E2"）
    chart_type: "bar"（横棒）/ "col"（縦棒）/ "bar_stacked"（積み上げ横棒）/ "col_stacked"（積み上げ縦棒）
    has_header_row: True=1行目がデータ系列名
    has_categories_col: True=左端列がカテゴリラベル
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        chart = BarChart()
        if "col" in chart_type:
            chart.type = "col"
        else:
            chart.type = "bar"
        chart.grouping = "stacked" if "stacked" in chart_type else "clustered"
        chart.overlap = 100 if "stacked" in chart_type else 0
        chart.title = title
        chart.width = width_cm
        chart.height = height_cm
        # データ範囲
        data_ref = Reference(
            ws,
            min_row=data_start_row,
            max_row=data_end_row,
            min_col=data_start_col + (1 if has_categories_col else 0),
            max_col=data_end_col
        )
        chart.add_data(data_ref, titles_from_data=has_header_row)
        # カテゴリ
        if has_categories_col:
            cat_ref = Reference(
                ws,
                min_row=data_start_row + (1 if has_header_row else 0),
                max_row=data_end_row,
                min_col=data_start_col
            )
            chart.set_categories(cat_ref)
        ws.add_chart(chart, chart_anchor_cell)
        _save(wb, filepath)
        return f"✅ 棒グラフ追加: '{title}'（{chart_anchor_cell} 基点）"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def add_line_chart(
    filepath: str,
    sheet_name: str,
    data_start_row: int,
    data_start_col: int,
    data_end_row: int,
    data_end_col: int,
    chart_anchor_cell: str,
    title: str = "",
    width_cm: float = 15,
    height_cm: float = 10,
    has_header_row: bool = True,
    has_categories_col: bool = True
) -> str:
    """
    折れ線グラフをシートに追加する。
    トレンド推移・時系列データの可視化に使う。
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        chart = LineChart()
        chart.title = title
        chart.width = width_cm
        chart.height = height_cm
        data_ref = Reference(
            ws,
            min_row=data_start_row,
            max_row=data_end_row,
            min_col=data_start_col + (1 if has_categories_col else 0),
            max_col=data_end_col
        )
        chart.add_data(data_ref, titles_from_data=has_header_row)
        if has_categories_col:
            cat_ref = Reference(
                ws,
                min_row=data_start_row + (1 if has_header_row else 0),
                max_row=data_end_row,
                min_col=data_start_col
            )
            chart.set_categories(cat_ref)
        ws.add_chart(chart, chart_anchor_cell)
        _save(wb, filepath)
        return f"✅ 折れ線グラフ追加: '{title}'（{chart_anchor_cell} 基点）"
    except Exception as e:
        return f"❌ {e}"


@mcp.tool()
def add_pie_chart(
    filepath: str,
    sheet_name: str,
    labels_start_row: int,
    labels_end_row: int,
    labels_col: int,
    values_col: int,
    chart_anchor_cell: str,
    title: str = "",
    width_cm: float = 12,
    height_cm: float = 10,
    has_header_row: bool = True
) -> str:
    """
    円グラフをシートに追加する。
    割合・構成比の可視化に使う。
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        chart = PieChart()
        chart.title = title
        chart.width = width_cm
        chart.height = height_cm
        data_ref = Reference(
            ws,
            min_row=labels_start_row,
            max_row=labels_end_row,
            min_col=values_col,
            max_col=values_col
        )
        chart.add_data(data_ref, titles_from_data=has_header_row)
        cat_ref = Reference(
            ws,
            min_row=labels_start_row + (1 if has_header_row else 0),
            max_row=labels_end_row,
            min_col=labels_col
        )
        chart.set_categories(cat_ref)
        ws.add_chart(chart, chart_anchor_cell)
        _save(wb, filepath)
        return f"✅ 円グラフ追加: '{title}'（{chart_anchor_cell} 基点）"
    except Exception as e:
        return f"❌ {e}"


# ─────────────────────────────────────────────────────────
# ■ 印刷・その他
# ─────────────────────────────────────────────────────────

@mcp.tool()
def set_print_settings(
    filepath: str,
    sheet_name: str,
    orientation: str = "landscape",
    paper_size: int = 9,
    fit_to_page: bool = True,
    print_area: Optional[str] = None,
    repeat_rows: Optional[int] = None
) -> str:
    """
    印刷設定を行う。
    orientation: "landscape"（横）/ "portrait"（縦）
    paper_size: 9=A4, 8=Letter, 11=A3
    fit_to_page: True=1ページに収める
    print_area: "A1:Z50" 形式（省略で全体）
    repeat_rows: ヘッダー行として繰り返す行番号（例: 1 → 毎ページ1行目を印刷）
    """
    try:
        wb = _load(filepath)
        ws = wb[sheet_name]
        from openpyxl.worksheet.page import PageMargins
        ws.page_setup.orientation = orientation
        ws.page_setup.paperSize = paper_size
        if fit_to_page:
            ws.page_setup.fitToPage = True
            ws.page_setup.fitToHeight = 0
            ws.page_setup.fitToWidth = 1
        if print_area:
            ws.print_area = print_area
        if repeat_rows:
            ws.print_title_rows = f"${repeat_rows}:${repeat_rows}"
        _save(wb, filepath)
        return f"✅ 印刷設定: {orientation} / A4={paper_size==9}"
    except Exception as e:
        return f"❌ {e}"


# ─────────────────────────────────────────────────────────
# エントリポイント
# ─────────────────────────────────────────────────────────
if __name__ == "__main__":
    _log("Excel MCP Server v2.0 起動中...")
    mcp.run(transport="stdio")
```

---

## 5. IDE設定（VS Code / Kiro）

### VS Code `.vscode/mcp.json`

```json
{
  "servers": {
    "excel-mcp": {
      "type": "stdio",
      "command": "python",
      "args": ["${workspaceFolder}/mcp_servers/excel/excel_mcp_server.py"],
      "env": {}
    }
  }
}
```

### Kiro `.kiro/settings/mcp.json`

```json
{
  "mcpServers": {
    "excel-mcp": {
      "command": "python",
      "args": ["${workspaceFolder}/mcp_servers/excel/excel_mcp_server.py"],
      "disabled": false,
      "autoApprove": [
        "create_workbook", "copy_template_to_output", "list_template_files",
        "add_sheet", "copy_sheet", "set_sheet_tab_color", "get_workbook_info",
        "list_sheets", "write_data", "write_cell", "read_sheet", "read_cell",
        "inspect_sheet", "find_cell_by_value", "replace_cell_value", "clear_range",
        "apply_style_range", "set_column_widths", "auto_fit_columns",
        "set_row_height", "merge_cells", "freeze_panes", "set_number_format",
        "add_hyperlink", "add_excel_table", "add_auto_filter",
        "add_dropdown_validation", "add_color_scale", "add_data_bar",
        "add_conditional_format_rule", "add_bar_chart", "add_line_chart",
        "add_pie_chart", "set_print_settings"
      ]
    }
  }
}
```

---

## 6. ツール完全一覧

### ワークブック操作

| ツール | 説明 | 主な用途 |
|--------|------|--------|
| `create_workbook` | 新規作成 | 白紙から開始 |
| `copy_template_to_output` | テンプレートをコピー | **テンプレートベース作業の第一歩** |
| `list_template_files` | テンプレート一覧 | 利用可能テンプレート確認 |
| `add_sheet` | シート追加 | 複数シート構成 |
| `copy_sheet` | シートコピー | テンプレートシートの複製 |
| `set_sheet_tab_color` | タブ色設定 | シート分類の視認性向上 |
| `get_workbook_info` | ファイル情報取得 | 構成確認 |
| `list_sheets` | シート一覧 | シート名確認 |

### データ読み書き

| ツール | 説明 | 主な用途 |
|--------|------|--------|
| `write_data` | 2次元配列の一括書き込み | テーブルデータ・パラメータ値 |
| `write_cell` | 単一セル書き込み | 個別値・数式 |
| `read_sheet` | シートデータ読み込み | 既存ファイルの読み取り |
| `read_cell` | 単一セル読み込み | セル情報確認 |
| `inspect_sheet` | シート構造の詳細把握 | テンプレート調査 |
| `find_cell_by_value` | テキスト検索 | 記入箇所（★,TBD）を探す |
| `replace_cell_value` | 値の一括置換 | プレースホルダーを実値に |
| `clear_range` | 値クリア（書式維持） | テンプレートのサンプルデータ削除 |

### 書式設定

| ツール | 説明 | 主な用途 |
|--------|------|--------|
| `apply_style_range` | 範囲スタイル設定 | ヘッダー色・罫線・文字色 |
| `set_column_widths` | 列幅指定 | 見やすいレイアウト |
| `auto_fit_columns` | 列幅自動調整 | 仕上げ処理 |
| `set_row_height` | 行高さ設定 | ヘッダー行の高さ |
| `merge_cells` | セル結合 | タイトル・分類ヘッダー |
| `freeze_panes` | ペイン固定 | ヘッダー行固定 |
| `set_number_format` | 数値フォーマット | 日付・通貨・パーセント |
| `add_hyperlink` | ハイパーリンク | URL・シート間リンク |

### テーブル・フィルター

| ツール | 説明 | 主な用途 |
|--------|------|--------|
| `add_excel_table` | Excelテーブル作成 | 構造化データ・自動フィルター付き |
| `add_auto_filter` | オートフィルター | 簡易フィルター設定 |
| `add_dropdown_validation` | ドロップダウン | ステータス・優先度入力規則 |

### 条件付き書式（Claudeが頻繁に使う機能）

| ツール | 説明 | 主な用途 |
|--------|------|--------|
| `add_color_scale` | カラースケール | 数値ヒートマップ（高低を色で表現） |
| `add_data_bar` | データバー | 数値をバーで視覚化 |
| `add_conditional_format_rule` | 条件ルール | 閾値超過で赤・特定値で強調 |

### チャート（Claudeが使うグラフ機能）

| ツール | 説明 | 主な用途 |
|--------|------|--------|
| `add_bar_chart` | 棒グラフ（縦・横・積み上げ） | 比較・内訳可視化 |
| `add_line_chart` | 折れ線グラフ | 時系列トレンド |
| `add_pie_chart` | 円グラフ | 構成比・割合 |

### 印刷

| ツール | 説明 | 主な用途 |
|--------|------|--------|
| `set_print_settings` | 印刷設定 | 印刷用紙・向き・フィットページ |

---

## 7. 2つのワークフロー詳細

### ワークフローA：テンプレートベース

```
社内テンプレート.xlsx（原本）
        ↓ 1. copy_template_to_output（原本保護・必須）
output/作業ファイル.xlsx
        ↓ 2. inspect_sheet（構造把握）
        ↓ 3. find_cell_by_value（★・TBD等の記入箇所を特定）
        ↓ 4. clear_range（サンプルデータを削除・書式は維持）
        ↓ 5. write_data / write_cell（要件に合った内容を記入）
        ↓ 6. replace_cell_value（残ったプレースホルダーを置換）
        ↓ 7. auto_fit_columns（仕上げ）
        → 完成（テンプレートの書式・レイアウトはそのまま維持）
```

**プロンプト例：パラメータシートをテンプレートから作成**

```
以下の手順でEC2パラメータシートを作成してください。

1. list_template_files で mcp_servers/excel/templates/ の一覧確認
2. parameter_sheet.xlsx を output/ec2_param_20260402.xlsx にコピー
3. inspect_sheet で各シートの構造を把握（記入欄の位置確認）
4. find_cell_by_value で「★」または「TBD」の箇所を特定
5. 以下の内容で記入：
   インスタンスタイプ: t3.medium
   リージョン: ap-northeast-1
   AMI: ami-0abcdef1234567890
   セキュリティグループ: sg-xxxxxxxxxx
6. auto_fit_columns で列幅調整
```

**プロンプト例：単体テスト仕様書テンプレートに追記**

```
unit_test_spec.xlsx をベースに以下を追加してください。

1. テンプレートを output/unit_test_ec2_ssm.xlsx にコピー
2. 「テストケース」シートの構造を inspect_sheet で確認
3. サンプルデータを clear_range で削除（書式維持）
4. 以下のテストケースを write_data で追加：
   No | テスト項目 | 前提条件 | 手順 | 期待結果 | 結果
   1  | SSM接続確認 | EC2起動済 | Session Manager接続 | 接続成功 | -
   2  | HTTPS疎通 | EC2起動済 | curl https://... | 200 OK | -
5. 「結果」列（F列）にドロップダウン（未実施/合格/不合格）を追加
6. ヘッダー行をカラースケールで視覚化
```

### ワークフローB：白紙から作成

```
create_workbook（新規作成）
        ↓ add_sheet（シート追加）
        ↓ write_data（データ一括書き込み）
        ↓ apply_style_range（ヘッダー・書式）
        ↓ add_excel_table（テーブル化・フィルター付き）
        ↓ add_color_scale / add_conditional_format_rule（視覚化）
        ↓ add_bar_chart / add_line_chart（グラフ）
        ↓ freeze_panes / set_print_settings（仕上げ）
        → 完成
```

**プロンプト例：RCA報告書を白紙から作成**

```
白紙から Wi-Fi障害RCA報告書を output/rca_wifi_20260402.xlsx に作成してください。

シート構成：
1. 「インシデント概要」（タブ色: 赤 #C00000）
   - タイトル行: A1:D1を結合、背景#1F4E79・白文字・太字
   - 項目: 発生日時・解決日時・影響範囲・重大度・対応ステータス
   - 対応ステータス列にドロップダウン（対応中/解決済/クローズ）

2. 「タイムライン」（タブ色: オレンジ #E2711D）
   - ヘッダー: 時刻 / イベント / 対応者 / 備考
   - Excelテーブルとして作成（TableStyleMedium9）
   - オートフィルター付き

3. 「根本原因分析」（タブ色: 青 #0070C0）
   - 5WHY形式（Why1〜Why5の列）
   - Cisco ISE / Intune / Firewallの連鎖障害を記載

全シート: ヘッダー背景 #1F4E79 / 白文字 / 1行目固定 / 列幅自動調整
```

---

## 8. Kiro Steering連携

**`.kiro/steering/excel-workflow-guide.md`** に保存することで、
ExcelファイルやOutputフォルダ関連のタスク時にAIが自動参照します。

```markdown
---
inclusion: auto
fileMatch: ["*.xlsx", "output/**", "**/parameter*", "**/spec*"]
---

# Excel MCP 作業ガイド

## ワークフロー選択
- 社内テンプレートあり → ワークフローA（コピー→調査→記入）
- 白紙 → ワークフローB（作成→書式→テーブル→グラフ）

## テンプレートベース作業の必須手順
1. copy_template_to_output を最初に実行（原本保護・必須）
2. inspect_sheet でシート構造を把握してから編集
3. find_cell_by_value で★・TBD等の記入箇所を特定
4. clear_range でサンプルデータを削除してから write_data

## テンプレート格納場所
mcp_servers/excel/templates/

## 出力先
output/ フォルダ（ファイル名に日付 YYYYMMDD を付ける）

## 社内カラーパレット
- ヘッダー: #1F4E79（ネイビー）/ フォント: #FFFFFF / 太字
- 小見出し: #2E75B6（ブルー）/ フォント: #FFFFFF
- 交互行: #EBF3FF（薄ブルー）
- 警告強調: #FF0000（赤）

## 数値フォーマット標準
- 日付: "yyyy/mm/dd"
- 円: "¥#,##0"
- パーセント: "0.0%"
- 整数カンマ: "#,##0"

## Excelテーブルのスタイル推奨
- 一般テーブル: TableStyleMedium9
- 重要テーブル: TableStyleMedium2
- サマリー: TableStyleLight16
```

---

*最終版 v2.0 | 作成日: 2026年4月 | Python 3.10+ / openpyxl 3.1+ / mcp 1.0+*
