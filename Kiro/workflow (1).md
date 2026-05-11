# Kiro 作業フロー定義（CSP共通）

チーム全体でKiroへの指示を統一し、個人のプロンプト作成能力に依存しないための定義です。
コーディング規約・Terraform制約・Spec命名ルールは各Steeringファイルが自動適用されます。

---

## 共通ルール

- クラウド種別（aws / azure / gcp）と案件名はチャットの指示から読み取ること
  - 例：「cms-kiro-test の設計書を作成」→ cloud=aws, project=cms-kiro-test
- インプット情報は `inputs/{cloud}/{project}/` を参照すること
- Specの出力先・命名は `spec-structure-rules.md` に従うこと

---

## パターン A：基本設計書の作成を依頼された場合

**参照すること：**

| ファイル | パス | 用途 |
|---|---|---|
| QA票 | `inputs/{cloud}/{project}/QA.xlsx` | 要件・制約・前提条件 |
| 基本設計書（AWS） | `inputs/{cloud}/{project}/インフラ基本設計書.xlsx` | フォーマット・パラメーター値（AWSのみ） |
| パラメーターシート | `inputs/{cloud}/{project}/parameter-sheet.xlsx` | パラメーター値（Azure / GCP） |
| 設計書生成手順 | `.kiro/skills/design-doc/design-doc.md` | 出力手順・ルール |

**構成図について：**
- `inputs/{cloud}/{project}/` に構成図が存在する場合
  → そのまま参照し、改善余地があればチャットに提案として記載すること
- `inputs/{cloud}/{project}/` に構成図が存在しない場合
  → draw.io MCP で自動生成すること（手順は `.kiro/skills/drawio-diagram/drawio.md` を参照）

**出力先：** `specs/{cloud}/{project}/`

---

## パターン B：Terraform コードの作成を依頼された場合

**参照すること：**

| ファイル | パス | 用途 |
|---|---|---|
| QA票 | `inputs/{cloud}/{project}/QA.xlsx` | 要件・制約・前提条件 |
| 基本設計書（AWS） | `inputs/{cloud}/{project}/インフラ基本設計書.xlsx` | パラメーター値（AWSのみ） |
| パラメーターシート | `inputs/{cloud}/{project}/parameter-sheet.xlsx` | パラメーター値（Azure / GCP） |
| モジュール利用ガイド | `.kiro/skills/terraform-code/terraform.md` | モジュール構成・呼び出しパターン |
| モジュールカタログ | `.kiro/skills/terraform-code/references/{cloud}-module-catalog.md` | モジュール一覧・依存関係 |
| 既存モジュール | `Eng-repos/{Cloud}Repos/` | 実装時に優先使用 |

**Terraform MCP の活用：**
- モジュールの詳細仕様・入出力が不明な場合は terraform MCP で `registry.terraform.io` を検索して補完すること
- プロバイダーのドキュメントが必要な場合も terraform MCP を使用すること

**出力先：** `src/{cloud}/{project}/`

---

## クラウド別スコープ

| クラウド | 状態 | Eng-repos | モジュールカタログ |
|---|---|---|---|
| AWS | ✅ 検証中 | `Eng-repos/AWSRepos/` | `aws-module-catalog.md` |
| Azure | ⏳ 検証完了後に追加 | `Eng-repos/AzureRepos/` | `azure-module-catalog.md` |
| GCP | ⏳ 検証完了後に追加 | `Eng-repos/GCPRepos/` | `gcp-module-catalog.md` |
