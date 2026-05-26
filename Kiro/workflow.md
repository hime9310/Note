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
- 成果物は `Outputs/{cloud}/{project}/` 配下に出力すること

---

## パターン A：基本設計書の作成を依頼された場合

**チャットに添付すること（ワークスペースからの自動参照不可）：**

| ファイル | 用途 | 対象CSP |
|---|---|---|
| `*QA*.xlsx` | 要件・制約・前提条件 | CSP共通 |
| `*基本設計書*.xlsx` | 設計書フォーマット・パラメーター値（「1.基本設計」シート） | CSP共通 |
| `*環境定義書*.xlsx` | 詳細パラメータ値（Azureのみ別ファイル） | Azure のみ |

**参照すること（ワークスペース内）：**

| ファイル | パス | 用途 |
|---|---|---|
| 設計書生成手順 | `.kiro/skills/design-doc/SKILL.md` | 出力手順・ルール |

**出力先：** `Outputs/{cloud}/{project}/設計書/design.md`

---

## パターン B：Terraform コードの作成を依頼された場合

**チャットに添付すること（ワークスペースからの自動参照不可）：**

| ファイル | 参照シート | 用途 | 対象CSP |
|---|---|---|---|
| `*QA*.xlsx` | 全シート | 要件・制約・前提条件 | CSP共通 |
| `*基本設計書*.xlsx` | `*インフラ構成*` シート（環境分すべて） | 環境別パラメーター値 | CSP共通 |
| `*環境定義書*.xlsx` | 全シート | 詳細パラメータ値（Azureのみ） | Azure のみ |

> `*インフラ構成*` シートは環境数分存在する。シート名から環境名を読み取り環境別にコードを生成すること。

**参照すること（ワークスペース内）：**

| ファイル | パス | 用途 |
|---|---|---|
| コード生成手順 | `.kiro/skills/terraform-code/SKILL.md` | モジュール構成・環境タイプ別ルール |
| モジュールカタログ | `.kiro/skills/terraform-code/references/{cloud}-module-catalog.md` | モジュール一覧・依存関係 |
| 既存モジュール | `EngRepos/AWS/`（AWS）/ `EngRepos/Azure/`（Azure）/ `EngRepos/GCP/`（GCP） | 実装時に優先使用 |

**Terraform MCP の活用：**
- モジュールの詳細仕様・入出力が不明な場合は terraform MCP で `registry.terraform.io` を検索して補完すること
- プロバイダーのドキュメントが必要な場合も terraform MCP を使用すること

**出力先：** `Outputs/{cloud}/{project}/code/{env}/`

```
Outputs/{cloud}/{project}/code/
├── {env1}/                     # シート名から環境名を読み取る
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── version.tf
│   ├── provider.tf
│   ├── {env1}.tfbackend
│   └── env/
│       ├── {env1}.tfvars
│       └── certs/              # 証明書格納フォルダ（空フォルダ作成のみ）
└── {env2}/
    └── ...
```

> 環境数はシート数に従う。2環境なら2フォルダ、3環境なら3フォルダ作成すること。

---

## パターン C：構成図の作成を依頼された場合

**チャットに添付すること：**

| ファイル | 用途 | 対象CSP |
|---|---|---|
| `*QA*.xlsx` | 要件・制約・前提条件 | CSP共通 |
| `*基本設計書*.xlsx` | アーキテクチャ概要・コンポーネント設計 | CSP共通 |
| 既存構成図（*.png / *.drawio） | 更新の場合のみ添付 | CSP共通 |

**参照すること（ワークスペース内）：**

| ファイル | パス | 用途 |
|---|---|---|
| 構成図生成手順 | `.kiro/skills/drawio-diagram/SKILL.md` | 生成手順・アイコンルール |

**出力先：** `Outputs/{cloud}/{project}/設計書/architecture.drawio`

---

## パターン D：設計書とコードを一括作成する場合

1チャットセッション内で完結する。添付ファイルを渡して指示するだけでよい。

**チャットに添付すること：**

| ファイル | 用途 | 対象CSP |
|---|---|---|
| `*QA*.xlsx` | 要件・制約・前提条件 | CSP共通 |
| `*基本設計書*.xlsx` | 設計書フォーマット・インフラ構成パラメーター | CSP共通 |
| `*環境定義書*.xlsx` | 詳細パラメータ値（Azureのみ） | Azure のみ |

**参照すること（ワークスペース内）：**

| ファイル | パス | 用途 |
|---|---|---|
| 設計書生成手順 | `.kiro/skills/design-doc/SKILL.md` | 設計書出力手順・ルール |
| コード生成手順 | `.kiro/skills/terraform-code/SKILL.md` | モジュール構成・環境タイプ別ルール |
| モジュールカタログ | `.kiro/skills/terraform-code/references/{cloud}-module-catalog.md` | モジュール一覧・依存関係 |
| 既存モジュール | `EngRepos/AWS/`（AWS）/ `EngRepos/Azure/`（Azure）/ `EngRepos/GCP/`（GCP） | 実装時に優先使用 |

**Kiroが以下の順番で自動生成・人間が各フェーズで承認：**

```
Step 1: requirements.md 生成 → 承認
         出力先: specs/{cloud}/{project}/requirements.md

Step 2: design.md 生成（基本設計書フォーマット準拠）→ 承認
         出力先: Outputs/{cloud}/{project}/設計書/design.md
         ※ 設計書として完結させること（specs/design.md は生成しない）

Step 3: tasks.md 生成 → 承認
         出力先: specs/{cloud}/{project}/tasks.md

Step 4: Terraform コード一式生成 → 承認
         出力先: Outputs/{cloud}/{project}/code/{env}/
```

---

## チャット指示の具体例

```
# パターンA（設計書のみ）
{案件名} の基本設計書を作成してください
※ QA票・基本設計書 を添付して送信

# パターンB（コードのみ）
{案件名} の Terraform コードを作成してください
※ QA票・基本設計書 を添付して送信

# パターンC（構成図のみ）
{案件名} の構成図を作成してください
※ QA票・基本設計書 を添付して送信

# パターンD（設計書+コード一括）
{案件名} の設計書とコードを作成してください
※ QA票・基本設計書 を添付して送信
```

> cloud と project を Kiro が自動判定します。
> 不安な場合は「AWS の {案件名}」のように明示してください。

---

## フォルダ構成まとめ

```
WorkSpace/
├── Inputs/                                   ← インプット情報
│   └── {cloud}/
│       └── {project}/
│           ├── *QA*.xlsx
│           ├── *基本設計書*.xlsx
│           └── *環境定義書*.xlsx（Azureのみ）
│
├── specs/                                    ← Kiro管理（変更不可）
│   └── {cloud}/
│       └── {project}/
│           ├── requirements.md               ← Kiro自動生成
│           └── tasks.md                      ← Kiro自動生成
│
└── Outputs/                                  ← 成果物
    └── {cloud}/
        └── {project}/
            ├── 設計書/
            │   ├── design.md                 ← パターンA/D出力
            │   └── architecture.drawio       ← パターンC出力
            └── code/
                ├── {env1}/                   ← パターンB/D出力
                │   ├── main.tf
                │   ├── variables.tf
                │   ├── outputs.tf
                │   ├── version.tf
                │   ├── provider.tf
                │   ├── {env1}.tfbackend
                │   └── env/
                │       ├── {env1}.tfvars
                │       └── certs/          ← 証明書格納フォルダ
                └── {env2}/
```

---

## CSP別インプット構成まとめ

| 項目 | AWS | Azure | GCP |
|---|---|---|---|
| 状態 | ✅ 検証中 | ⏳ 保留 | ⏳ 保留 |
| QA票 | `*QA*.xlsx` | `*QA*.xlsx` | `*QA*.xlsx` |
| 基本設計書 | `*基本設計書*.xlsx` | `*基本設計書*.xlsx` | `*基本設計書*.xlsx` |
| コード生成参照シート | `*インフラ構成*` | `*インフラ構成*` | `*インフラ構成*` |
| 詳細パラメータ | 基本設計書内に含む | `*環境定義書*.xlsx`（別ファイル） | 基本設計書内に含む |
| 既存モジュール | `EngRepos/AWS/` | `EngRepos/Azure/` | `EngRepos/GCP/` |
| モジュールカタログ | `aws-module-catalog.md` | `azure-module-catalog.md` | `gcp-module-catalog.md` |