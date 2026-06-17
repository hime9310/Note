# .kiro/skills — ドキュメント生成スキル集

このフォルダは、Kiro に「専門的な Excel / PowerPoint を作る能力」を
オンデマンドで持たせるための **Agent Skill** をまとめたものです。

```
.kiro/skills/
├── README.md            ← このファイル（全体説明・ライブラリ解説）
├── pptx-builder/
│   ├── SKILL.md         ← PPT生成の手順・テンプレ選択・会社要件
│   └── reference/       ← dark.pptx / light.pptx を置く
│       └── README.md
└── excel-builder/
    ├── SKILL.md         ← Excel生成の手順・テンプレ選択・体裁
    └── reference/       ← 基本設計書 / 単体テスト / 結合テスト.xlsx を置く
        └── README.md
```

## スキルの呼び出し方
- 依頼内容が SKILL.md の description と一致すると、Kiro が自動でスキルを読み込む。
- 明示的に使いたいときは、チャットで `/pptx-builder` または `/excel-builder` と入力する。

---

## 1. 環境準備

```bash
pip install openpyxl pandas python-pptx
```

⚠️ `pip` でライブラリを入れた Python のバージョンと、実際にスクリプトを実行する
`python3` のバージョンが **同じ** である必要があります。違うと実行時に
`ModuleNotFoundError: No module named 'openpyxl'` などが出ます。

```bash
python3 --version
python3 -m pip show openpyxl   # 表示されれば同一環境、OK
```

| ライブラリ | 主担当 | 役割 |
|---|---|---|
| `openpyxl`     | Excel    | `.xlsx` の読み書き・体裁・グラフ |
| `python-pptx`  | PPT      | `.pptx` の読み書き・レイアウト・表/グラフ |
| `pandas`       | データ処理 | 集計・整形（上の2つと組み合わせて使う補助） |

---

## 2. openpyxl 詳解（Excel 担当）

`.xlsx` / `.xlsm` を **読み書き** できる純 Python ライブラリ。Excel 本体が無くても動く。

### データ構造
`Workbook（ブック） → Worksheet（シート） → Cell（セル）` の3層。

```python
from openpyxl import Workbook, load_workbook

wb = Workbook()                    # 新規ブック
ws = wb.active                     # アクティブシート
ws.title = "売上"                  # シート名

wb2 = load_workbook("template.xlsx")   # 既存を開く（書式・グラフを保持）
```

### セルへの読み書き
```python
ws["A1"] = "商品名"                # 列名+行番号で指定
ws.cell(row=2, column=1, value="りんご")   # 行・列番号で指定
value = ws["A1"].value             # 読み取り
```

### 体裁（スタイル）
`openpyxl.styles` から各種オブジェクトを使う。

```python
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

ws["A1"].font = Font(bold=True, color="FFFFFF")
ws["A1"].fill = PatternFill("solid", fgColor="1F4E79")     # 背景色
ws["A1"].alignment = Alignment(horizontal="center", vertical="center")
ws["B2"].number_format = "#,##0"     # 3桁区切り。通貨は "¥#,##0"、率は "0.0%"
```

### 行・列・表示
```python
ws.freeze_panes = "A2"                       # 1行目を固定
ws.column_dimensions["A"].width = 20         # 列幅
ws.merge_cells("A1:C1")                       # セル結合
```

### グラフ
`openpyxl.chart` で折れ線・棒・円などを挿入できる。

```python
from openpyxl.chart import LineChart, Reference

chart = LineChart()
chart.title = "月次推移"
data = Reference(ws, min_col=2, max_col=4, min_row=1, max_row=13)
cats = Reference(ws, min_col=1, min_row=2, max_row=13)
chart.add_data(data, titles_from_data=True)
chart.set_categories(cats)
ws.add_chart(chart, "F2")
```

### 数式の扱い（重要な注意）
- 数式は **文字列として書ける**：`ws["D2"] = "=SUM(A2:C2)"`。
- ただし openpyxl 自身は **計算しない**。値は Excel で開いた瞬間に再計算される。
- 計算済みの値を読みたいときは `load_workbook(path, data_only=True)` で開く
  （＝最後に Excel が保存した結果が読める。未保存だと None）。

### 得意 / 苦手
- 得意：体裁付きの表、グラフ挿入、テンプレートの流用、定型帳票の量産。
- 苦手：計算の実行、ピボットテーブル生成、図形・SmartArt・画像装飾。

---

## 3. python-pptx 詳解（PowerPoint 担当）

`.pptx` を **読み書き** できる純 Python ライブラリ。テンプレートのマスター・
レイアウト・配色を継承して、スライドを組み立てられるのが最大の強み。

### データ構造
`Presentation → Slides → Slide → Shapes / Placeholders` の階層。

```python
from pptx import Presentation

prs = Presentation()                  # 新規（既定は4:3。16:9は下記）
prs = Presentation("template.pptx")   # テンプレを開く（マスター・配色を継承）
```

### スライドの追加（レイアウトを再利用）
```python
layout = prs.slide_layouts[1]         # テンプレ内のレイアウト（index/種類はテンプレ依存）
slide = prs.slides.add_slide(layout)
slide.placeholders[0].text = "タイトル"     # タイトルプレースホルダー
slide.placeholders[1].text = "本文の内容"   # 本文プレースホルダー
```

### テキストボックスと書式
```python
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor

box = slide.shapes.add_textbox(Inches(1), Inches(1), Inches(8), Inches(1))
tf = box.text_frame
p = tf.paragraphs[0]
run = p.add_run(); run.text = "見出し"
run.font.size = Pt(28); run.font.bold = True
run.font.color.rgb = RGBColor(0x1F, 0x4E, 0x79)
```

### 表
```python
rows, cols = 3, 3
tbl = slide.shapes.add_table(rows, cols, Inches(1), Inches(2), Inches(8), Inches(2)).table
tbl.cell(0, 0).text = "項目"
```

### グラフ
```python
from pptx.chart.data import CategoryChartData
from pptx.enum.chart import XL_CHART_TYPE

data = CategoryChartData()
data.categories = ["1月", "2月", "3月"]
data.add_series("売上", (100, 120, 140))
slide.shapes.add_chart(XL_CHART_TYPE.LINE, Inches(1), Inches(2), Inches(8), Inches(4), data)
```

### 16:9 で新規作成したいとき
```python
prs.slide_width  = Inches(13.333)
prs.slide_height = Inches(7.5)
```

### 単位
`Inches` / `Pt` / `Cm` / `Emu` を使う（python-pptx の内部単位は EMU）。

### 得意 / 苦手
- 得意：テンプレのレイアウト/マスター継承、表・グラフ・画像の配置、定型スライド量産。
- 苦手：
  - **スライドの複製**にクリーンな API が無い（テンプレ内の特定ページを丸ごとコピーするのは不安定）。
    → 各ページ型の「空レイアウト」を用意し `add_slide()` で増やす方式が安全。
  - 画像へのレンダリング（プレビュー生成）はできない。
  - アニメーション・画面切り替え・SmartArt・一部のテーマ効果は扱えない。

---

## 4. pandas（補助：データ処理）

集計・整形を担当し、結果を openpyxl / python-pptx に渡す。

```python
import pandas as pd

df = pd.read_csv("sales.csv")              # 読み込み（read_excel もある）
df["前月比"] = df["売上"].pct_change()      # 計算
monthly = df.groupby("月")["売上"].sum()    # 集計
df.to_excel("out.xlsx", index=False)       # 簡易出力（体裁は openpyxl で追加）
```

典型的な流れ：**pandas で集計 → openpyxl で体裁付け／グラフ**、
または **pandas で整形 → python-pptx でスライド化**。

---

## 5. まとめ

- **Excel が欲しい** → openpyxl（＋集計は pandas）。`excel-builder` スキルが担当。
- **PPT が欲しい** → python-pptx。`pptx-builder` スキルが担当。
- どちらも「テンプレートがあれば継承し、無ければゼロから作る」方針。
  テンプレートは各スキルの `reference/` に置く。
- 生成後は必ず実行してファイルを確認し、エラーは直して成功するまで繰り返す。