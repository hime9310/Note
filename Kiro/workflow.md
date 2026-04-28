# Kiro 作業フロー定義（CSP共通）

チーム全体でKiroへの指示を統一し、個人のプロンプト作成能力に依存しないための定義です。

---

## 1. 共通ルール

- クラウド種別（aws / azure / gcp）と案件名はチャットの指示から読み取ること
  - 例：「cms-kiro-test の設計書を作成」→ cloud=aws, project=cms-kiro-test
- インプット情報は必ず `inputs/{cloud}/{project}/` を参照すること
- Specの出力先・命名は `spec-structure-rules.md` に従うこと
- コーディング規約は `coding-standards.md` に従うこと（常時自動適用）
- Terraform制約は `terraform-rules.md` に従うこと（.tfファイル操作時に自動適用）
- Kiroは人間の承認なしに次のPhaseへ進まないこと

---

## 2. インプット情報の参照先

案件ごとに以下を参照すること。

| ファイル | 内容 | 備考 |
|---|---|---|
| `QA.xlsx` | 利用者とのQA票 | 要件・制約・前提条件 |
| `インフラ基本設計書.xlsx` | 設計書フォーマット＋パラメーターシート | AWSは本ファイルにパラメーター含む |
| `parameter-sheet.xlsx` | パラメーターシート | Azure等、別ファイルの場合 |
| `architecture.png` | 案件ごとの構成図 | 存在する場合のみ参照 |

---

## 3. 作業フロー

### Phase 1：requirements.md の作成を依頼された場合

**参照：**
1. `inputs/{cloud}/{project}/QA.xlsx`
2. `inputs/{cloud}/{project}/インフラ基本設計書.xlsx`

**出力：** `specs/{cloud}/{project}/requirements.md`

**形式：**
- ユーザーストーリー
- 機能要件 / 非機能要件
- 受け入れ基準（チェックボックス形式）

---

### Phase 2：基本設計書の作成を依頼された場合

**参照：**
1. `inputs/{cloud}/{project}/インフラ基本設計書.xlsx`（フォーマット・構成）
2. `inputs/{cloud}/{project}/QA.xlsx`（要件・制約）
3. `inputs/{cloud}/{project}/parameter-sheet.xlsx`（別ファイルの場合のみ）
4. `inputs/{cloud}/{project}/architecture.png`（存在する場合のみ）
5. `specs/{cloud}/{project}/requirements.md`（存在する場合）

**出力：** `specs/{cloud}/{project}/design.md`（Markdown形式）

**ルール：**
- Excelのシート構成・項目名をそのまま踏襲すること
- 不明・未確定の値は `[要確認]` とマーク（空白禁止）
- 構成図がある場合はアーキテクチャの記述に反映すること
- 改善余地がある場合は `[提案]` としてコメントを追記すること
- 詳細は `.kiro/skills/design-doc/design-doc.md` を参照すること

---

### Phase 3：Terraformコードの作成を依頼された場合

**参照：**
1. `specs/{cloud}/{project}/design.md`
2. `specs/{cloud}/{project}/requirements.md`（受け入れ基準）
3. `Eng-repos/AWSRepos/` 配下の既存モジュール（優先使用）
4. `.kiro/skills/terraform-code/references/module-catalog.md`

**出力：** `src/{cloud}/{project}/`

| ファイル | 役割 |
|---|---|
| `main.tf` | モジュール呼び出し・リソース定義 |
| `variables.tf` | 入力変数（description・type 必須） |
| `outputs.tf` | 出力値定義 |
| `version.tf` | Terraform・Providerバージョン制約 |
| `provider.tf` | Providerの設定 |

**ルール：**
- 既存モジュール優先・新規作成は最小限
- 変数はすべて `variables.tf` に集約（ハードコード禁止）
- デプロイスクリプト・CI/CDは生成しない（デプロイは人間が手動実施）
- 詳細は `.kiro/skills/terraform-code/terraform.md` を参照すること

---

## 4. コード生成時の必須制約（terraform-rules.md・coding-standards.md 準拠）

### フォーマット
- インデントは半角スペース2個
- `terraform fmt` を適用すること
- `variables.tf` の各変数には `description` と `type` を必ず記載

### 命名規則
- リソースブロック名は特別な理由がない限り `this` を使用
- moduleブロック名は役割が分かる名称を使用
  （例：`rds_common`、`fargate_webapp`、`s3_bucket_for_waf_log`）
- ブランチ名：`feature-{バックログ課題キー}` 形式

### コード記述ルール
- `count` / `for_each` はリソースブロック内1行目に記載・末尾に空行1行
- 空値は `null` を使用（空文字 `""` は禁止）

### バージョン制約
- Terraform本体：`~> 1.14.0`
- AWS Provider：`hashicorp/aws ~> 6.14.1`
- Azure Provider：`hashicorp/azurerm ~> 3.0`
- GCP Provider：`hashicorp/google ~> 6.0`
- `~>` を使うこと（`>=` は使わない）

### コミットメッセージ
- `feat` / `fix` / `modify` / `docs` / `refactor` のプレフィックスをつける

---

## 5. 検証フェーズのスコープ

| クラウド | 状態 | Eng-repos参照先 |
|---|---|---|
| AWS | ✅ 検証中 | `Eng-repos/AWSRepos/` |
| Azure | ⏳ 保留 | `Eng-repos/AzureRepos/`（検証完了後） |
| GCP | ⏳ 保留 | `Eng-repos/GCPRepos/`（検証完了後） |
