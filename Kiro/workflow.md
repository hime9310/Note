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
- インプットファイルはチャットに添付して渡すこと（ワークスペースのパス参照は使わない）
- Specの出力先・命名は `spec-structure-rules.md` に従うこと

---

## パターン A：基本設計書の作成を依頼された場合

### チャットへの添付ファイル

| ファイル | 用途 | 対象CSP |
|---|---|---|
| `*QA*.xlsx` | 要件・制約・前提条件 | CSP共通 |
| `*基本設計書*.xlsx` | 設計書フォーマット（章立て・項目名の踏襲元） | CSP共通 |
| `*環境定義書*.xlsx` | 詳細パラメータ値（Azureのみ別ファイルで存在） | Azure のみ |

### 作成ルール
- 添付された基本設計書の **「1.基本設計」シートのフォーマットのみ** を使用すること
- フォーマットの構成・章立て・項目名は**変更しないこと**
- QA票の内容を参照してフォーマットに沿って値を埋めること
- 添付のフォーマットと内容が異なる場合は修正して合わせること
- 項目が足りない・そもそも存在しない場合は適宜増減して対応すること
- 不明・未確定の値は `[要確認]` とマークすること（空白禁止）
- 構成図（*.png / *.drawio）が添付されている場合は内容を参照してアーキテクチャに反映すること
- 改善余地がある場合は `[提案]` としてコメントを追記すること
- Kiroは人間の承認なしに次のPhaseへ進まないこと

**出力先：** `specs/{cloud}/{project}/design.md`（Markdown形式）

---

## パターン B：Terraform コードの作成を依頼された場合

### チャットへの添付ファイル

| ファイル | 用途 | 対象CSP |
|---|---|---|
| `*QA*.xlsx` | 要件・制約・前提条件 | CSP共通 |
| `*基本設計書*.xlsx` | パラメーター値の参照元 | CSP共通 |
| `*環境定義書*.xlsx` | 詳細パラメータ値（Azureのみ） | Azure のみ |

### 参照すること（ワークスペース内）

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
# パターンA（基本設計書）
{案件名} の基本設計書を作成してください
※ チャットに QA票.xlsx と 基本設計書.xlsx を添付して送信

# パターンB（コード作成）
{案件名} の Terraform コードを作成してください
※ チャットに QA票.xlsx と 基本設計書.xlsx を添付して送信
```

> cloud と project を Kiro が inputs 配下のフォルダ名で自動判定します。
> 曖昧な場合は「AWS の {案件名}」のように明示してください。

---

## CSP別インプット構成まとめ

| 項目 | AWS | Azure | GCP |
|---|---|---|---|
| 状態 | ✅ 検証中 | ⏳ 保留 | ⏳ 保留 |
| QA票 | `*QA*.xlsx` | `*QA*.xlsx` | `*QA*.xlsx` |
| 基本設計書（フォーマット） | `*基本設計書*.xlsx` | `*基本設計書*.xlsx` | `*基本設計書*.xlsx` |
| 詳細パラメータ | 基本設計書内に含む | `*環境定義書*.xlsx`（別ファイル） | 基本設計書内に含む |
| 既存モジュール | `EngRepos/AWS/` | `EngRepos/Azure/` | `EngRepos/GCP/` |
| モジュールカタログ | `aws-module-catalog.md` | `azure-module-catalog.md` | `gcp-module-catalog.md` |
