---
inclusion: always
---
# Kiro 作業フロー定義（CSP共通）

チーム全体でKiroへの指示を統一し、個人のプロンプト作成能力に依存しないための定義です。
コーディング規約・Terraform制約・Spec命名ルールは各Steeringファイルが自動適用されます。

## 共通ルール

- クラウド種別（aws / azure / gcp）と案件名はチャットの指示から読み取ること
  - 例：「cms-kiro-test の設計書を作成」→ cloud=aws, project=cms-kiro-test
- インプット情報は `inputs/{cloud}/{project}/` を参照すること
- Specの出力先・命名は `spec-structure-rules.md` に従うこと

## パターン A：基本設計書の作成を依頼された場合

### 参照すること

| ファイル | パス | 用途 | 対象CSP |
|---|---|---|---|
| QA票 | `inputs/{cloud}/{project}/*QA*.xlsx` | 要件・制約・前提条件 | CSP共通 |
| 基本設計書 | `inputs/{cloud}/{project}/*基本設計書*.xlsx` | 設計書フォーマット（章立て・項目名）の踏襲元。QAを参照の上、このフォーマットに従って「1.基本設計」を作成する | CSP共通 |
| 環境定義書 | `inputs/azure/{project}/*環境定義書*.xlsx` | 詳細パラメータ値（Azureのみ別ファイルで存在） | Azure のみ |
| 設計書生成手順 | `.kiro/skills/design-doc/design-doc.md` | 出力手順・ルール | CSP共通 |

### 構成図について
- `inputs/{cloud}/{project}/` に構成図（*.png / *.drawio）が存在する場合
  → そのまま参照し、改善余地があればチャットに提案として記載すること
- `inputs/{cloud}/{project}/` に構成図が存在しない場合
  → draw.io MCP で自動生成すること（手順は `.kiro/skills/drawio-diagram/drawio.md` を参照）

**出力先：** `specs/{cloud}/{project}/`

## パターン B：Terraform コードの作成を依頼された場合

### 参照すること

| ファイル | パス | 用途 | 対象CSP |
|---|---|---|---|
| QA票 | `inputs/{cloud}/{project}/*QA*.xlsx` | 要件・制約・前提条件 | CSP共通 |
| 基本設計書 | `inputs/{cloud}/{project}/*基本設計書*.xlsx` | 設計書フォーマット・設計内容の参照元 | CSP共通 |
| 環境定義書 | `inputs/azure/{project}/*環境定義書*.xlsx` | 詳細パラメータ値（Azureのみ別ファイルで存在） | Azure のみ |
| モジュール利用ガイド | `.kiro/skills/terraform-code/terraform.md` | モジュール構成・呼び出しパターン | CSP共通 |
| モジュールカタログ | `.kiro/skills/terraform-code/references/{cloud}-module-catalog.md` | モジュール一覧・依存関係 | CSP共通 |
| 既存モジュール | `EngRepos/AWS/`（AWS）/ `EngRepos/Azure/`（Azure）/ `EngRepos/GCP/`（GCP） | 実装時に優先使用 | CSP共通 |

### Terraform MCP の活用
- モジュールの詳細仕様・入出力が不明な場合は terraform MCP で `registry.terraform.io` を検索して補完すること
- プロバイダーのドキュメントが必要な場合も terraform MCP を使用すること

**出力先：** `src/{cloud}/{project}/`

## チャット指示の具体例

```
{案件名} の基本設計書を作成してください
{案件名} の Terraform コードを作成してください
```

> cloud と project を Kiro が inputs 配下のフォルダ名で自動判定します。
> 曖昧な場合は「AWS の {案件名}」のように明示してください。

## CSP別インプット構成まとめ

| 項目 | AWS | Azure | GCP |
|---|---|---|---|
| 状態 |  検証中 | 保留 | ⏳ 保留 |
| QA票 | `*QA*.xlsx` | `*QA*.xlsx` | `*QA*.xlsx` |
| 基本設計書（フォーマット） | `*基本設計書*.xlsx` | `*基本設計書*.xlsx` | `*基本設計書*.xlsx` |
| 詳細パラメータ | 基本設計書内に含む | `*環境定義書*.xlsx`（別ファイル） | 基本設計書内に含む |
| 既存モジュール | `EngRepos/AWS/` | `EngRepos/Azure/` | `EngRepos/GCP/` |
| モジュールカタログ | `aws-module-catalog.md` | `azure-module-catalog.md` | `gcp-module-catalog.md` |