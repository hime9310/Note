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
- インプット情報は `inputs/{cloud}/{project}/` を参照すること
- Specの出力先・命名は `spec-structure-rules.md` に従うこと

---

## パターン A：基本設計書の作成を依頼された場合

### AWS の場合

| ファイル | パス | 用途 |
|---|---|---|
| QA票 | `inputs/aws/{project}/*QA*.xlsx` | 要件・制約・前提条件 |
| インフラ基本設計書 | `inputs/aws/{project}/*基本設計書*.xlsx` | フォーマット・パラメーター値（シート内に含む） |

### Azure の場合（要確認）

| ファイル | パス | 用途 |
|---|---|---|
| QA票 | `inputs/azure/{project}/*QA*.xlsx` | 要件・制約・前提条件 |
| 詳細設計書 | `inputs/azure/{project}/*基本設計書*.xlsx` | 設計フォーマット |
| パラメータシート | `inputs/azure/{project}/*環境定義書*.xlsx` | パラメーター値（別ファイル） |

### GCP の場合（検証完了後に確定）

| ファイル | パス | 用途 |
|---|---|---|
| QA票 | `inputs/gcp/{project}/*QA*.xlsx` | 要件・制約・前提条件 |
| パラメーターシート | `inputs/gcp/{project}/*基本設計書*.xlsx` | フォーマット・パラメーター値（シート内に含む） |

### 共通参照

| ファイル | パス | 用途 |
|---|---|---|
| 設計書生成手順 | `.kiro/skills/design-doc/design-doc.md` | 出力手順・ルール |

### 構成図について
- `inputs/{cloud}/{project}/` に構成図（*.png / *.drawio）が存在する場合
  → そのまま参照し、改善余地があればチャットに提案として記載すること
- `inputs/{cloud}/{project}/` に構成図が存在しない場合
  → draw.io MCP で自動生成すること（手順は `.kiro/skills/drawio-diagram/drawio.md` を参照）

**出力先：** `specs/{cloud}/{project}/`

---

## パターン B：Terraform コードの作成を依頼された場合

### 参照すること

| ファイル | パス | 用途 |
|---|---|---|
| QA票 | `inputs/{cloud}/{project}/*QA*.xlsx` | 要件・制約・前提条件 |
| 設計書（AWS） | `inputs/aws/{project}/*基本設計書*.xlsx` | パラメーター値 |
| 詳細設計書（Azure） | `inputs/azure/{project}/*基本設計書*.xlsx` | パラメーター値 |
| パラメータシート（Azure） | `inputs/azure/{project}/*環境定義書*.xlsx` | パラメーター値 |
| モジュール利用ガイド | `.kiro/skills/terraform-code/terraform.md` | モジュール構成・呼び出しパターン |
| モジュールカタログ | `.kiro/skills/terraform-code/references/{cloud}-module-catalog.md` | モジュール一覧・依存関係 |
| 既存モジュール | `Eng-repos/{Cloud}Repos/` | 実装時に優先使用 |

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

> cloud と project を Kiro が inputs 配下のフォルダ名で自動判定します。
> 曖昧な場合は「AWS/Azure/GCP の {案件名}」のように明示してください。