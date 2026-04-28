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

## パターンA：基本設計書の作成を依頼された場合

**参照すること：**

| ファイル | パス | 用途 |
|---|---|---|
| QA票 | `inputs/{cloud}/{project}/QA.xlsx` | 要件・制約・前提条件 |
| 基本設計書（AWS） | `inputs/{cloud}/{project}/インフラ基本設計書.xlsx` | フォーマット・パラメーター値 |
| パラメーターシート | `inputs/{cloud}/{project}/parameter-sheet.xlsx` | パラメーター値（CSPにより異なる） |
| 設計書生成手順 | `.kiro/skills/design-doc/design-doc.md` | 出力手順・ルール |

**出力先：** `specs/{cloud}/{project}/`

---

## パターンB：Terraformコードの作成を依頼された場合

**参照すること：**

| ファイル | パス | 用途 |
|---|---|---|
| QA票 | `inputs/{cloud}/{project}/QA.xlsx` | 要件・制約・前提条件 |
| 基本設計書（AWS） | `inputs/{cloud}/{project}/インフラ基本設計書.xlsx` | パラメーター値 |
| モジュール利用ガイド | `.kiro/skills/terraform-code/terraform.md` | モジュール構成・呼び出しパターン |
| モジュールカタログ | `.kiro/skills/terraform-code/references/aws-module-catalog.md` | モジュール一覧・依存関係 |
| 既存モジュール | `Eng-repos/AWSRepos/` | 実装時に優先使用 |

**出力先：** `src/{cloud}/{project}/`

---

## 検証フェーズのスコープ

| クラウド | 状態 | インプットのパラメーターシート |
|---|---|---|
| AWS | ✅ 検証中 | インフラ基本設計書.xlsx 内に含む |
| Azure | ⏳ 保留 | parameter-sheet.xlsx（別ファイル・要確認） |
| GCP | ⏳ 保留 | 未定 |
