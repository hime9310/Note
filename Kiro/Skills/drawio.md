# draw.io 構成図生成ガイド

Kiro向けに、draw.io MCP Server（Tool Server）を使った構成図の生成・更新手順を定義するドキュメントです。

---

## 1. 使用する MCP ツール

| ツール | 用途 |
|---|---|
| `open_drawio_xml` | XML形式で構成図を生成・draw.io で開く（メイン） |
| `open_drawio_csv` | CSVデータから図を生成 |
| `open_drawio_mermaid` | Mermaid 記法から図を生成 |

---

## 2. アイコンの使用ルール

draw.io の公式アイコンを使用すること。
アイコンのスタイル文字列は Kiro が保有する draw.io XML の知識から生成すること。

| クラウド | アイコン形式 |
|---|---|
| AWS | `shape=mxgraph.aws4.*` |
| Azure | `shape=mxgraph.azure.*` |
| GCP | `shape=mxgraph.gcp2.*` |

スタイル文字列が不明な場合は汎用シェイプで代替し、`[要確認]` とラベルを付けること。

---

## 3. 構成図を新規作成する場合

### 参照すること

| 優先度 | ファイル | 用途 |
|---|---|---|
| 必須 | `specs/{cloud}/{project}/design.md` | アーキテクチャ概要・コンポーネント設計 |
| 必須（AWS / GCP） | `inputs/{cloud}/{project}/*基本設計書*.xlsx` | 構成・パラメーター値 |
| 必須（Azure） | `inputs/azure/{project}/*基本設計書*.xlsx` | 構成|
| 必須（Azure） | `inputs/azure/{project}/*環境定義書*.xlsx` | パラメーター値 |

### 手順
1. design.md のアーキテクチャ概要を元に必要なコンポーネントを洗い出す
2. クラウド種別に応じた公式アイコンを使って構成図の XML を生成する
3. `open_drawio_xml` で draw.io に渡す
4. 保存先：`inputs/{cloud}/{project}/architecture.drawio`

### ルール
- 構成図は必ずレイヤーを分けて作成すること
  - レイヤー例：Network / Compute / Storage / Security
- 不明なコンポーネントは汎用シェイプで代替し `[要確認]` とラベルを付けること
- 人間の承認後に保存すること

---

## 4. 構成図を更新する場合

### 参照すること
- `inputs/{cloud}/{project}/` 配下の既存構成図（*.drawio / *.png）

### 手順
1. 既存の構成図（architecture.drawio または architecture.png）を参照する
2. design.md の変更点を反映して更新する
3. 改善余地がある場合はチャットに提案として記載してから更新すること

