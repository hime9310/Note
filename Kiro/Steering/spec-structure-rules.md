---
inclusion: always
---
# Spec フォルダ・ファイル命名規則

チーム全体でSpecフォルダ・ファイルの構成を統一するためのルールです。

---

## 1. フォルダ構成

### Inputs（インプット情報）
```
Inputs/{cloud}/{project}/
```

### Spec（Kiro管理）
```
specs/{cloud}/{project}/
```

### Outputs（成果物）
```
Outputs/{cloud}/{project}/
├── 設計書/
└── code/
    └── {env}/
```

| プレースホルダー | 説明 | 値 |
|---|---|---|
| `{cloud}` | クラウド種別 | `aws` / `azure` / `gcp` |
| `{project}` | 案件名（Inputs配下と同名） | 例：`cms-kiro-test` |
| `{env}` | 環境識別子（インフラ構成シート名から読み取る） | 例：`staging` / `production` / `dev` |

### 例

```
Inputs/
└── aws/
    └── cms-kiro-test/
        ├── *QA*.xlsx
        └── *基本設計書*.xlsx

specs/
└── aws/
    └── cms-kiro-test/          # Kiro管理（変更不可）
        ├── requirements.md
        └── tasks.md

Outputs/
└── aws/
    └── cms-kiro-test/
        ├── 設計書/
        │   ├── design.md
        │   └── architecture.drawio
        └── code/
            ├── staging/
            │   ├── main.tf
            │   ├── variables.tf
            │   ├── outputs.tf
            │   ├── version.tf
            │   ├── provider.tf
            │   ├── staging.tfbackend
            │   └── env/
            │       ├── staging.tfvars
            │       └── certs/          ← 証明書格納フォルダ
            └── production/
                ├── main.tf
                ├── variables.tf
                ├── outputs.tf
                ├── version.tf
                ├── provider.tf
                ├── production.tfbackend
                └── env/
                    ├── production.tfvars
                    └── certs/          ← 証明書格納フォルダ
```

---

## 2. project の命名ルール

- すべて **小文字・ハイフン区切り**（スネークケース・大文字禁止）
- `{サービス名}-{用途}` の形式を基本とする
- **Inputs配下の案件フォルダ名と必ず一致させること**

| 良い例 | 悪い例 |
|---|---|
| `cms-kiro-test` | `CMS_Kiro_Test` |
| `ec2-rds-hub` | `EC2RDSHub` |
| `aks-cluster` | `aks_cluster` |

---

## 3. ファイルの出力先

| ファイル | 出力先 | 生成者 | パターン |
|---|---|---|---|
| `requirements.md` | `specs/{cloud}/{project}/` | Kiro自動生成 | D |
| `tasks.md` | `specs/{cloud}/{project}/` | Kiro自動生成 | D |
| `design.md`（基本設計書） | `Outputs/{cloud}/{project}/設計書/` | Kiro生成・人間が承認 | A / D |
| `architecture.drawio`（構成図） | `Outputs/{cloud}/{project}/設計書/` | Kiro生成・人間が承認 | C |
| Terraformコード | `Outputs/{cloud}/{project}/code/{env}/` | Kiro生成・人間が承認 | B / D |

---

## 4. ファイル生成ルール

- Kiroは人間の承認なしに次のPhaseへ進まないこと
- 各ファイルは人間がレビュー・承認してから次へ進む
- 不明項目は空白にせず必ず `[要確認]` とマークすること
- フォルダはKiroが自動作成するため、事前の手動作成は不要
- `certs/` フォルダは空フォルダとして作成すること（実ファイルは人間が別途配置）

---

## 5. Inputs・specs・Outputs の対応関係

案件フォルダ名は Inputs・specs・Outputs すべて同名で統一する。

```
Inputs/aws/cms-kiro-test/         ← インプット情報（チャット添付で渡す）
specs/aws/cms-kiro-test/          ← Kiroが管理するSpec（requirements / tasks）
Outputs/aws/cms-kiro-test/        ← 成果物（設計書・構成図・コード）
```
