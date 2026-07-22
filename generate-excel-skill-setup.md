# generate-excel スキル構築手順 (既存リポジトリ組み込み版)

`cms-eng-spec-driven-development` の既存構成に沿って、design.md → 納品用 Excel の変換パイプラインを **`generate-excel` スキル**として組み込む手順書。

## 全体方針 (再掲)

```
[generate-design スキル]      [generate-excel スキル (新設)]
Kiro が doc-format 規約に   →  決定的な Python スクリプトで
沿って design.md を生成        MD → YAML → Excel 変換 + 検証
```

- LLM の仕事は design.md の生成まで。**Excel 変換はスクリプトのみ**が行う (エージェントに Excel を直接編集させない)
- Excel はテンプレートのコピーから**毎回新規生成** → 余り行・列崩れが原理的に発生しない
- クラウド別 (aws / azure / gcp) の差分は「テンプレート + mapping」の差し替えで吸収し、**スクリプトは共通**

---

## 1. リポジトリへの組み込み (ディレクトリ構成)

★=新規追加 / ✎=既存ファイルへ追記。それ以外は既存のまま。

```
cms-eng-spec-driven-development/
├── .kiro/                                  # ★Git 管理 (変換一式もチーム共有資産)
│   ├── steering/                           # (変更なし)
│   ├── agents/                             # (変更なし・予約枠)
│   ├── hooks/
│   │   └── excel-build.kiro.hook           # ★(任意) design.md 保存時の自動変換 → §6
│   ├── settings/                           # (変更なし)
│   └── skills/
│       ├── generate-design/
│       │   ├── SKILL.md
│       │   ├── parts/
│       │   └── references/
│       │       └── {cloud}-doc-format.md   # ✎ Excel 変換互換規約を追記 → §2
│       ├── generate-code/                  # (変更なし)
│       ├── generate-diagram/               # (変更なし)
│       └── generate-excel/                 # ★新設スキル
│           ├── SKILL.md                    # エージェント向けの実行手順
│           ├── requirements.txt            # openpyxl / PyYAML
│           ├── scripts/                    # 決定的変換 (LLM 不使用)
│           │   ├── build.py                #   一括実行 (--project / --cloud)
│           │   ├── md_to_yaml.py           #   design.md → 中間 YAML
│           │   ├── yaml_to_excel.py        #   YAML + テンプレート → Excel
│           │   └── validate.py             #   MD と Excel の一致検証
│           └── templates/                  # 納品フォーマット (テンプレートと対応表はペア)
│               ├── aws-design-template.xlsx
│               ├── aws-mapping.yaml
│               ├── azure-design-template.xlsx
│               ├── azure-mapping.yaml
│               ├── gcp-design-template.xlsx
│               └── gcp-mapping.yaml
├── outputs/                                # 🚫各自ローカル (既存ルール通り)
│   └── {project}/
│       ├── design.md                       # generate-design の成果物 (変換の入力)
│       ├── design.yaml                     # ★中間データ (自動生成)
│       └── design.xlsx                     # ★納品物 (自動生成)
├── AGENTS.md                               # ✎ generate-excel の項を追記 → §7
└── ...                                     # (変更なし)
```

- Git 管理: `.kiro/skills/generate-excel/` 一式 (スクリプト・テンプレート・mapping) は★Git 管理。`outputs/` 配下の yaml / xlsx は既存ルール通りローカルのみ
- `outputs/{project}/` 直下に design.md がある前提で書いています。実際の配置が異なる場合は `build.py` のパス組み立て部分 (1 箇所) を調整してください

---

## 2. `{cloud}-doc-format.md` への追記 (✎)

design.md の書式規約は steering ではなく、既存の **`generate-design/references/{cloud}-doc-format.md`** に集約します (現行アーキテクチャの「形式定義は references/」に合わせる)。各クラウドのファイルに以下を追記してください。

### 追記例 (共通ルール部分・全クラウド同文)

```markdown
## Excel 変換互換規約 (必須)

design.md は generate-excel スキルによる Excel 自動変換の入力となる。以下を厳守すること。

- 各設計項目は `## セクション名` とし、直後に Markdown テーブルを 1 つだけ置く
- セクション名・列名・列順は本書のセクション定義と完全一致させる (追加・省略・改名・並び替え禁止)
- テーブルの 1 行目はヘッダ、2 行目は区切り行 (`|---|`)、3 行目以降がデータ
- セル内に改行・パイプ (`|`) を含めない。複数値は `, ` 区切りで 1 セルに書く
- 該当なしのセルは空欄のまま残す (`-` や `N/A` を書かない)
- テーブル以外の説明文をセクション内に書かない
```

### セクション定義 (クラウド別に定義)

同ファイル内に、そのクラウドで出力するセクションと列を列挙します。**ここが Excel テンプレートの列と 1:1 対応**になります。aws-doc-format.md の例:

```markdown
## セクション定義

### 文書情報
| 項目 | 値 |
(項目は「システム名」「版数」「作成日」の 3 行固定)

### VPC設計
| No | リソース名 | CIDR | リージョン | 備考 |

### サブネット設計
| No | サブネット名 | CIDR | AZ | 種別 | 備考 |

### セキュリティグループ設計
| No | SG名 | 方向 | プロトコル | ポート | ソース/宛先 | 備考 |
```

> **3 点セットの同期ルール**: セクション・列の構成は
> `{cloud}-doc-format.md` / `{cloud}-design-template.xlsx` / `{cloud}-mapping.yaml`
> の 3 つで常に一致させる。フォーマット変更時はこの 3 点だけを直し、スクリプトは触らない。

---

## 3. `generate-excel/SKILL.md` (★)

エージェントには「スクリプトを実行する」「NG なら design.md 側を直す」役割だけを持たせます。

```markdown
# generate-excel: 設計書 Excel 変換

outputs/{project}/design.md を納品用 Excel (design.xlsx) に変換するスキル。

## 原則
- 変換は必ず scripts/build.py で行う。エージェントが Excel を直接生成・編集してはならない
- 検証 NG の原因が design.md 側にある場合は、generate-design/references/{cloud}-doc-format.md
  の規約に沿って design.md を修正してから再実行する

## 実行手順
1. 対象案件 ({project}) とクラウド (aws/azure/gcp) を確認する
2. outputs/{project}/design.md の存在を確認する (なければ generate-design を先に実行)
3. 変換を実行する:
   python .kiro/skills/generate-excel/scripts/build.py --project {project} --cloud {cloud}
4. validate.py の結果で分岐する:
   - OK → outputs/{project}/design.xlsx を成果物として報告する
   - 「mapping 未登録のセクション」「列名不一致」
       → design.md が doc-format 規約から逸脱している。design.md を修正し手順 3 を再実行
   - 「行数不一致」「値不一致」
       → スクリプトまたはテンプレート側の不具合の可能性。修正せず内容を人間に報告する
```

### `generate-excel/requirements.txt`

```txt
openpyxl>=3.1
PyYAML>=6.0
```

```bash
pip install -r .kiro/skills/generate-excel/requirements.txt
```

(Python 3.10 以上)

---

## 4. スクリプト一式 (★ `generate-excel/scripts/`)

### 4-1. `build.py` — 一括実行 (案件・クラウドを引数で指定)

```python
#!/usr/bin/env python3
"""design.md → YAML → Excel → 検証 を一括実行する。

使い方 (リポジトリルートで実行):
  python .kiro/skills/generate-excel/scripts/build.py --project sample-pj --cloud aws
"""
import argparse
import subprocess
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]   # .kiro/skills/generate-excel
REPO_ROOT = Path(__file__).resolve().parents[4]   # リポジトリルート
SCRIPTS = SKILL_DIR / "scripts"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True,
                        help="outputs/ 配下の案件フォルダ名")
    parser.add_argument("--cloud", required=True, choices=["aws", "azure", "gcp"])
    args = parser.parse_args()

    # ---- パス組み立て (配置が変わったらここだけ直す) ----
    out_dir = REPO_ROOT / "outputs" / args.project
    design_md = out_dir / "design.md"
    design_yaml = out_dir / "design.yaml"
    design_xlsx = out_dir / "design.xlsx"
    template = SKILL_DIR / "templates" / f"{args.cloud}-design-template.xlsx"
    mapping = SKILL_DIR / "templates" / f"{args.cloud}-mapping.yaml"
    # ----------------------------------------------------

    if not design_md.exists():
        sys.exit(f"ERROR: {design_md} がありません。先に generate-design を実行してください。")
    if not template.exists() or not mapping.exists():
        sys.exit(f"ERROR: {args.cloud} 用のテンプレートまたは mapping がありません。")

    steps = [
        [sys.executable, str(SCRIPTS / "md_to_yaml.py"),
         str(design_md), "-o", str(design_yaml)],
        [sys.executable, str(SCRIPTS / "yaml_to_excel.py"),
         "--data", str(design_yaml), "--template", str(template),
         "--mapping", str(mapping), "-o", str(design_xlsx)],
        [sys.executable, str(SCRIPTS / "validate.py"),
         "--data", str(design_yaml), "--mapping", str(mapping),
         "--excel", str(design_xlsx)],
    ]
    for cmd in steps:
        print(f"\n=== {Path(cmd[1]).name} ===")
        if subprocess.run(cmd).returncode != 0:
            sys.exit(1)
    print(f"\n完了: {design_xlsx}")


if __name__ == "__main__":
    main()
```

### 4-2. `md_to_yaml.py` — design.md → 中間 YAML

```python
#!/usr/bin/env python3
"""design.md を中間データ (YAML) に変換する。

想定フォーマット ({cloud}-doc-format.md の Excel 変換互換規約):
  - `## セクション名` の直後に Markdown テーブルが 1 つ置かれる
  - テーブルの 1 行目がヘッダ、2 行目が区切り行 (|---|---|)
"""
import argparse
import re
import sys
from pathlib import Path

import yaml


def split_table_row(line: str) -> list[str]:
    """`| a | b |` 形式の行をセルのリストに分解する。"""
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [cell.strip() for cell in line.split("|")]


def is_separator_row(cells: list[str]) -> bool:
    """|---|:---:| のような区切り行かどうか。"""
    return any(cells) and all(re.fullmatch(r":?-{3,}:?", c) for c in cells if c)


def parse_design_md(text: str) -> dict:
    sections: dict[str, list[dict]] = {}
    current_section: str | None = None
    header: list[str] | None = None

    for raw_line in text.splitlines():
        line = raw_line.rstrip()

        m = re.match(r"^##\s+(.+)$", line)
        if m:
            current_section = m.group(1).strip()
            sections[current_section] = []
            header = None
            continue

        if current_section is None:
            continue

        if line.strip().startswith("|"):
            cells = split_table_row(line)
            if is_separator_row(cells):
                continue
            if header is None:
                header = cells
                continue
            row = {h: (cells[i] if i < len(cells) else "")
                   for i, h in enumerate(header)}
            sections[current_section].append(row)
        elif line.strip() == "":
            header = None  # 空行でテーブル終了とみなす

    return {"sections": sections}


def main() -> None:
    parser = argparse.ArgumentParser(description="design.md → YAML 変換")
    parser.add_argument("input", type=Path, help="design.md のパス")
    parser.add_argument("-o", "--output", type=Path, required=True)
    args = parser.parse_args()

    text = args.input.read_text(encoding="utf-8")
    data = parse_design_md(text)

    if not data["sections"]:
        sys.exit("ERROR: セクションが見つかりません。design.md の形式を確認してください。")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, allow_unicode=True, sort_keys=False)

    for name, rows in data["sections"].items():
        print(f"  - {name}: {len(rows)} 行")
    print(f"OK: {len(data['sections'])} セクションを {args.output} に出力しました")


if __name__ == "__main__":
    main()
```

### 4-3. `yaml_to_excel.py` — YAML + テンプレート → Excel

```python
#!/usr/bin/env python3
"""中間データ (YAML) + Excel テンプレート → 納品用 Excel を生成する。

ポイント:
  - 既存ファイルを編集せず、毎回テンプレートのコピーから新規生成する
  - 可変行は「雛形行」の書式をコピーして必要数だけ増やす
  - 同一シートに複数の表がある場合は下の表から処理し、行挿入による位置ずれを防ぐ
"""
import argparse
import shutil
from copy import copy
from pathlib import Path

import yaml
from openpyxl import load_workbook
from openpyxl.utils import column_index_from_string
from openpyxl.worksheet.worksheet import Worksheet


def convert_value(text: str):
    """純粋な整数文字列だけ int に変換する (No 列などを数値として扱うため)。"""
    if text != "" and text.lstrip("-").isdigit():
        return int(text)
    return text


def copy_row_style(ws: Worksheet, src_row: int, dst_row: int, max_col: int) -> None:
    """src_row の書式 (フォント・罫線・塗り・配置・表示形式) を dst_row にコピーする。"""
    for col in range(1, max_col + 1):
        src = ws.cell(row=src_row, column=col)
        dst = ws.cell(row=dst_row, column=col)
        dst.font = copy(src.font)
        dst.border = copy(src.border)
        dst.fill = copy(src.fill)
        dst.alignment = copy(src.alignment)
        dst.number_format = src.number_format
    ws.row_dimensions[dst_row].height = ws.row_dimensions[src_row].height


def write_fields(ws: Worksheet, section_rows: list[dict], field_map: dict) -> None:
    """key-value 型セクション (文書情報など) を固定セルに書き込む。"""
    values = {row.get("項目", ""): row.get("値", "") for row in section_rows}
    for key, cell_ref in field_map.items():
        ws[cell_ref] = values.get(key, "")


def write_table(ws: Worksheet, section_rows: list[dict], conf: dict) -> None:
    """テーブル型セクションを雛形行を起点に展開する。"""
    start_row: int = conf["start_row"]
    col_indexes = {name: column_index_from_string(letter)
                   for name, letter in conf["columns"].items()}
    max_col = max(col_indexes.values())
    n = len(section_rows)

    if n == 0:
        # データ 0 件なら雛形行の値だけクリア (書式は残す)
        for col in col_indexes.values():
            ws.cell(row=start_row, column=col, value=None)
        return

    # 雛形行の直下に (n-1) 行挿入し、書式をコピー
    if n > 1:
        ws.insert_rows(start_row + 1, amount=n - 1)
        for i in range(1, n):
            copy_row_style(ws, start_row, start_row + i, max_col)

    for i, row in enumerate(section_rows):
        for name, col in col_indexes.items():
            ws.cell(row=start_row + i, column=col,
                    value=convert_value(row.get(name, "")))


def main() -> None:
    parser = argparse.ArgumentParser(description="YAML + テンプレート → Excel 生成")
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--mapping", type=Path, required=True)
    parser.add_argument("-o", "--output", type=Path, required=True)
    args = parser.parse_args()

    data = yaml.safe_load(args.data.read_text(encoding="utf-8"))
    mapping = yaml.safe_load(args.mapping.read_text(encoding="utf-8"))
    sections: dict = data["sections"]

    # 1. テンプレートをコピー (既存ファイルの編集はしない)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(args.template, args.output)

    # 2. コピーしたファイルに書き込む
    #    同一シート内は start_row の大きい表 (下の表) から処理する
    wb = load_workbook(args.output)
    order = sorted(mapping["sheets"],
                   key=lambda c: (c["sheet_name"], -c.get("start_row", 0)))
    for conf in order:
        name = conf["source_section"]
        if name not in sections:
            print(f"WARNING: design.md にセクション '{name}' がありません。スキップします。")
            continue
        ws = wb[conf["sheet_name"]]
        if conf["type"] == "fields":
            write_fields(ws, sections[name], conf["fields"])
        elif conf["type"] == "table":
            write_table(ws, sections[name], conf)
            print(f"  - {conf['sheet_name']}: {len(sections[name])} 行を書き込み")

    wb.save(args.output)
    print(f"OK: {args.output} を生成しました")


if __name__ == "__main__":
    main()
```

### 4-4. `validate.py` — MD と Excel の一致検証

```python
#!/usr/bin/env python3
"""生成した Excel が design.md (YAML) と一致しているか検証する。

チェック内容:
  1. design.md にあって mapping 未登録のセクション (取りこぼし)
  2. mapping にあって design.md にないセクション
  3. テーブルの行数一致 (YAML vs Excel)
  4. 列名の一致 (design.md のヘッダ vs mapping の columns)
  5. セル値の一致 (全セル突き合わせ)
"""
import argparse
import sys
from pathlib import Path

import yaml
from openpyxl import load_workbook
from openpyxl.utils import column_index_from_string

MAX_VALUE_ERRORS = 20  # 値不一致の報告上限


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--mapping", type=Path, required=True)
    parser.add_argument("--excel", type=Path, required=True)
    args = parser.parse_args()

    sections = yaml.safe_load(args.data.read_text(encoding="utf-8"))["sections"]
    mapping = yaml.safe_load(args.mapping.read_text(encoding="utf-8"))
    wb = load_workbook(args.excel)

    errors: list[str] = []
    mapped = {c["source_section"] for c in mapping["sheets"]}

    # 1. 取りこぼし / 2. 過剰定義
    for name in sections:
        if name not in mapped:
            errors.append(f"mapping 未登録のセクション: '{name}' (Excel に反映されていません)")
    for name in mapped:
        if name not in sections:
            errors.append(f"design.md に存在しないセクション: '{name}'")

    value_errors = 0
    for conf in mapping["sheets"]:
        if conf["type"] != "table" or conf["source_section"] not in sections:
            continue
        rows = sections[conf["source_section"]]
        ws = wb[conf["sheet_name"]]
        cols = {name: column_index_from_string(letter)
                for name, letter in conf["columns"].items()}

        # 3. 行数一致: 先頭列を上から走査して Excel 側の行数を数える
        first_col = next(iter(cols.values()))
        excel_count, r = 0, conf["start_row"]
        while ws.cell(row=r, column=first_col).value not in (None, ""):
            excel_count += 1
            r += 1
        if excel_count != len(rows):
            errors.append(f"シート '{conf['sheet_name']}': 行数不一致 "
                          f"(design.md: {len(rows)} 行 / Excel: {excel_count} 行)")

        # 4. 列名一致
        if rows:
            md_cols, map_cols = set(rows[0]), set(cols)
            if md_cols != map_cols:
                errors.append(f"セクション '{conf['source_section']}': 列名不一致 "
                              f"(design.md のみ: {sorted(md_cols - map_cols)} / "
                              f"mapping のみ: {sorted(map_cols - md_cols)})")

        # 5. セル値一致
        for i, row in enumerate(rows):
            for name, col in cols.items():
                cell = ws.cell(row=conf["start_row"] + i, column=col)
                excel_val = "" if cell.value is None else str(cell.value)
                if excel_val != str(row.get(name, "")):
                    value_errors += 1
                    if value_errors <= MAX_VALUE_ERRORS:
                        errors.append(
                            f"値不一致 {conf['sheet_name']}!{cell.coordinate}: "
                            f"MD='{row.get(name, '')}' / Excel='{excel_val}'")
    if value_errors > MAX_VALUE_ERRORS:
        errors.append(f"(値不一致は他に {value_errors - MAX_VALUE_ERRORS} 件)")

    if errors:
        print("NG: 検証エラー")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    print("OK: すべての検証を通過しました")


if __name__ == "__main__":
    main()
```

---

## 5. テンプレートと mapping (★ `generate-excel/templates/`)

### 5-1. `{cloud}-design-template.xlsx` の準備 (クラウドごとに手動で 1 回)

1. 納品フォーマットの Excel をコピーして `aws-design-template.xlsx` 等として保存
2. 可変行の表は、**書式付きのデータ行を 1 行だけ残して**それ以外のデータ行を削除する
   (残した 1 行が「雛形行」になり、スクリプトが書式ごと必要数コピーする)
3. 雛形行の行番号を控え、mapping の `start_row` に書く

```
[サブネットシートのテンプレート例]
行 1-2: タイトル・ヘッダ部 (固定)
行 3  : 表のヘッダ行 (固定)
行 4  : 雛形行 ← 罫線・フォント・表示形式付き。start_row: 4
行 5- : (データ行はすべて削除しておく)
```

### 5-2. `{cloud}-mapping.yaml` (aws の例)

MD のセクションと Excel のシート/セルの対応を定義。doc-format のセクション定義と 1:1 で揃える。

```yaml
sheets:
  # key-value 型: 固定セルへの書き込み
  - sheet_name: "表紙"
    type: "fields"
    source_section: "文書情報"
    fields:
      システム名: "C4"
      版数: "C5"
      作成日: "C6"

  # テーブル型: 雛形行を起点に可変行を展開
  - sheet_name: "VPC"
    type: "table"
    source_section: "VPC設計"
    start_row: 4
    columns:
      No: "B"
      リソース名: "C"
      CIDR: "D"
      リージョン: "E"
      備考: "F"

  - sheet_name: "サブネット"
    type: "table"
    source_section: "サブネット設計"
    start_row: 4
    columns:
      No: "B"
      サブネット名: "C"
      CIDR: "D"
      AZ: "E"
      種別: "F"
      備考: "G"

  - sheet_name: "セキュリティグループ"
    type: "table"
    source_section: "セキュリティグループ設計"
    start_row: 4
    columns:
      No: "B"
      SG名: "C"
      方向: "D"
      プロトコル: "E"
      ポート: "F"
      ソース/宛先: "G"
      備考: "H"
```

azure / gcp も同様に、各クラウドの doc-format のセクション定義に合わせて作成します。

---

## 6. 実行方法

### 手動実行 (リポジトリルートで)

```bash
python .kiro/skills/generate-excel/scripts/build.py --project sample-pj --cloud aws
```

### Kiro から実行

generate-design 完了後に「generate-excel を実行して」と指示すれば、SKILL.md の手順に従って build.py が実行され、NG 時は design.md の修正 → 再実行までエージェントが行います。

### hooks/ への発展 (任意・予約枠の初適用候補)

`.kiro/hooks/` に「`outputs/**/design.md` の保存をトリガーに generate-excel を実行する」フックを置けば、設計書更新のたびに Excel が自動再生成されます。フック定義は Kiro の Hook 作成 UI から作るのが確実です (プロンプトに「保存されたファイルの案件・クラウドを特定し build.py を実行、validate NG なら doc-format 規約に沿って design.md を修正して再実行」と書く)。

---

## 7. 既存ファイルへの追記 (✎)

- **AGENTS.md**: スキル一覧に `generate-excel` の項を追加 (役割: design.md → 納品 Excel 変換。前提: generate-design 完了。入力: outputs/{project}/design.md。出力: outputs/{project}/design.xlsx)
- **README.md**: セットアップ手順に `pip install -r .kiro/skills/generate-excel/requirements.txt` を追記
- **.gitignore**: outputs/ 配下が既に除外されていれば追加作業なし (design.yaml / design.xlsx もローカルのみ)

---

## 8. 運用上の注意点

### テンプレート関連

- **結合セル**: 雛形行にセル結合があると、行挿入時に結合が複製されず崩れることがある (openpyxl のバージョンで挙動差あり)。**雛形行にはセル結合を使わない**のが安全。必須なら行挿入後に `ws.merge_cells()` で結合し直す処理を追加
- **同一シートに複数の表**: スクリプトは下の表から処理するため動作するが、`fields` の固定セルは**表より上**に配置すること (表の行挿入で下の要素は押し下げられるため)
- **Excel テーブル機能 (ListObject)**: 行挿入で範囲が自動拡張されない。テンプレートでは通常の罫線表にする
- **印刷範囲・条件付き書式**: 行挿入でずれる場合がある。印刷範囲は広めに設定しておくか、クラウドごとの初回変換時に目視確認
- **`.xlsm` の場合**: `load_workbook(path, keep_vba=True)` にしないとマクロが消える
- **日付・数値の表示形式**はテンプレートの雛形行に設定しておけばコピーされるため、スクリプト側の対応は不要

### パイプライン関連

- **フォーマット変更時は 3 点セット** (`{cloud}-doc-format.md` / テンプレート xlsx / mapping.yaml) だけを直す。スクリプトは共通のまま触らない
- **Kiro の出力が規約からずれた場合**: validate.py のセクション・列名チェックで検知される。SKILL.md の手順により design.md 側を修正して再実行するフローになる
- **pandas は使わない**: `to_excel` はテンプレートの書式を破壊するため、このパイプラインでは openpyxl + PyYAML のみ
- **行の繰り返しが複雑になったら** (小計行・グループ見出し・ネスト等): 雛形行 1 行方式の限界なので、Excel セルに Jinja2 タグを書ける **xltpl** への置き換えを検討。その場合も Step 構成 (doc-format 規約 → 中間 YAML → テンプレートから新規生成 → 検証) はそのまま流用できる
