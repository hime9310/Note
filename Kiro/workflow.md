---
inclusion: always
---
# Kiro 作業フロー定義（CSP共通）

チーム全体でKiroへの指示を統一し、個人のプロンプト作成能力に依存しないための定義です。
コーディング規約・Terraform制約・Spec命名ルールは各Steeringファイルが自動適用されます。

---

## 共通ルール

- クラウド種別（aws / azure / gcp）と案件名はチャットの指示から読み取ること
  - 例：「cms-kiro-test の設計書を作成」→ cloud=aws, project=cms-kiro-test
- Specの出力先・命名は `spec-structure-rules.md` に従うこと

---

## パターン A：基本設計書の作成を依頼された場合

**チャットに添付すること（ワークスペースからの自動参照不可）：**

| ファイル | 用途 | 対象CSP |
|---|---|---|
| `*QA*.xlsx` | 要件・制約・前提条件 | CSP共通 |
| `*基本設計書*.xlsx` | 設計書フォーマット・パラメーター値 | CSP共通 |
| `*環境定義書*.xlsx` | 詳細パラメータ値（Azureのみ別ファイル） | Azure のみ |

**参照すること（ワークスペース内）：**

| ファイル | パス | 用途 |
|---|---|---|
| 設計書生成手順 | `.kiro/skills/design-doc/SKILL.md` | 出力手順・ルール |

**出力先：** `specs/{cloud}/{project}/`

---

## パターン B：Terraform コードの作成を依頼された場合

**チャットに添付すること（ワークスペースからの自動参照不可）：**

| ファイル | 用途 | 対象CSP |
|---|---|---|
| `*QA*.xlsx` | 要件・制約・前提条件 | CSP共通 |
| `*基本設計書*.xlsx` | パラメーター値の参照元 | CSP共通 |
| `*環境定義書*.xlsx` | 詳細パラメータ値（Azureのみ） | Azure のみ |

**参照すること（ワークスペース内）：**

| ファイル | パス | 用途 |
|---|---|---|
| モジュール利用ガイド | `.kiro/skills/terraform-code/SKILL.md` | モジュール構成・呼び出しパターン |
| モジュールカタログ | `.kiro/skills/terraform-code/references/{cloud}-module-catalog.md` | モジュール一覧・依存関係 |
| 既存モジュール | `EngRepos/AWS/`（AWS）/ `EngRepos/Azure/`（Azure）/ `EngRepos/GCP/`（GCP） | 実装時に優先使用 |

### Terraform MCP の活用
- モジュールの詳細仕様・入出力が不明な場合は terraform MCP で `registry.terraform.io` を検索して補完すること
- プロバイダーのドキュメントが必要な場合も terraform MCP を使用すること

**出力先：** `src/{cloud}/{project}/`

---

## チャット指示の具体例

```
{案件名} の基本設計書を作成してください
{案件名} の Terraform コードを作成してください
```

> cloud と project を Kiro が自動判定します。
> 曖昧な場合は「AWS の {案件名}」のように明示してください。

---

## CSP別インプット構成まとめ

| 項目 | AWS | Azure | GCP |
|---|---|---|---|
| 状態 | ✅ 検証中 | ⏳ 保留 | ⏳ 保留 |
| QA票 | `*QA*.xlsx` | `*QA*.xlsx` | `*QA*.xlsx` |
| 基本設計書 | `*基本設計書*.xlsx` | `*基本設計書*.xlsx` | `*基本設計書*.xlsx` |
| 詳細パラメータ | 基本設計書内に含む | `*環境定義書*.xlsx`（別ファイル） | 基本設計書内に含む |
| 既存モジュール | `EngRepos/AWS/` | `EngRepos/Azure/` | `EngRepos/GCP/` |
| モジュールカタログ | `aws-module-catalog.md` | `azure-module-catalog.md` | `gcp-module-catalog.md` |
