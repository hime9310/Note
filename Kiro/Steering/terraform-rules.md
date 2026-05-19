---
inclusion: fileMatch
fileMatchPattern: "**/*.tf"
---
# Terraform 共通ルール

ディレクトリ構成・バージョン制約など、環境・チームを横断する共通ルールをまとめたドキュメントです。
新しい知見が得られた場合はチームで合意の上、随時更新すること。

---

## 1. ディレクトリ構成

### 採用構成：Terraform公式推奨例

```
（リポジトリルート）/
├── modules/                    # 再利用可能なモジュール群
│   ├── compute/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── database/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── network/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
├── prod/                       # 本番環境
│   ├── backend.tf
│   ├── main.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── version.tf
│   └── outputs.tf
└── staging/                    # ステージング環境
    ├── backend.tf
    ├── main.tf
    ├── provider.tf
    ├── variables.tf
    ├── version.tf
    └── outputs.tf
```

---

## 2. 各ファイルの役割

| ファイル | 役割 |
|---|---|
| `main.tf` | モジュール呼び出しとリソース定義のメイン |
| `variables.tf` | 入力変数の定義（`description`・`type` を必ず記載） |
| `version.tf` | TerraformおよびProviderのバージョン制約を定義 |
| `provider.tf` | Providerの設定（リージョン・認証情報等） |
| `backend.tf` | リモートステート（tfstate）の保存先設定 |
| `outputs.tf` | 他から参照される出力値の定義 |

---

## 3. バージョン制約（共通ルール）

### Terraform本体のバージョン

`version.tf` に以下の形式で記載する：

```hcl
terraform {
  required_version = "~> 1.14.0"
}
```

### バージョン制約の書き方：`~>` を使う（悲観的制約）

| 書き方 | 意味 | 採用 |
|---|---|---|
| `~> 1.14` | 1.14以上・2.0未満 | 推奨 |
| `~> 1.14.0` | 1.14.0以上・1.15.0未満 | 推奨 |
| `>= 1.14` | 1.14以上すべて | **非推奨** |

> Terraform公式は破壊的変更が起こりえない **悲観的制約（`~>`）** のみを設けることを推奨しています。
> `>=` を使うと将来のメジャーバージョンアップ時に予期しない破壊的変更が発生するリスクがあります。

**運用補足：** 本プロジェクトでは `~> 1.14.0` を採用しています。

---

## 4. CSP別バージョン制約

CSPごとに `required_providers` で明示し、`~>` で互換範囲を制御する。

### AWS（検証中）

```hcl
# version.tf
terraform {
  required_version = "~> 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.14.1"
    }
  }
}
```

```hcl
# provider.tf
provider "aws" {
  region = var.region
}
```

### Azure（検証完了後に追加予定）

```hcl
# version.tf
terraform {
  required_version = "~> 1.14.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}
```

```hcl
# provider.tf
provider "azurerm" {
  features {}
}
```

### GCP（検証完了後に追加予定）

```hcl
# version.tf
terraform {
  required_version = "~> 1.14.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
```

```hcl
# provider.tf
provider "google" {
  project = var.project
  region  = var.region
}
```

---

## 5. 関連ドキュメント

- [terraform.md](./terraform.md) - モジュールの場所・呼び出しパターン
- [aws-module-catalog.md](./module-catalog.md) - モジュール一覧
- [coding-standards.md](./coding-standards.md) - コーディング規約
