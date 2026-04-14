# Terraform 共通ルール

> ディレクトリ構成・バージョン制約など、環境・チームを横断する共通ルールをまとめたドキュメントです。

---

## 1. ディレクトリ構成

### 採用構成：Terraform公式推奨例

本プロジェクトでは **Terraform公式が推奨するフォルダ構成** を採用します。

```
(リポジトリルート)/
├── modules/               # 再利用可能なモジュール群
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
├── prod/                  # 本番環境
│   ├── backend.tf         # リモートステート設定
│   ├── main.tf            # モジュール呼び出し
│   ├── provider.tf        # プロバイダー設定
│   ├── variables.tf       # 変数定義
│   └── version.tf         # Terraform・プロバイダーバージョン制約
└── staging/               # ステージング環境
    ├── backend.tf
    ├── main.tf
    ├── provider.tf
    ├── variables.tf
    └── version.tf
```

### この構成のメリット

- **環境ごとに専用ディレクトリ**を持つため、tfstateファイルが環境ごとに分離される
- 環境ごとに変数やバックエンドの設定を個別に管理できる
- 環境間のリソース差分が多い場合に特に適している

### この構成のデメリット

- バグや仕様変更が発生してコード修正をする場合、**環境ごとのtfファイルをすべて修正する必要がある**ため手間がかかりやすい

> **補足（DRY原則を意識する場合）：** 環境間のコード重複を減らしたい場合は、ワークスペース（Workspace）活用や共通変数ファイルの切り出し等も検討できますが、まずは本構成を基準とします。

---

## 2. 各ファイルの役割

| ファイル名 | 役割 |
|---|---|
| `main.tf` | モジュール呼び出しとリソース定義のメイン |
| `variables.tf` | 入力変数の定義（`description`・`type`を必ず記載） |
| `version.tf` | TerraformおよびProviderのバージョン制約を定義 |
| `provider.tf` | Providerの設定（リージョン・認証情報等） |
| `backend.tf` | リモートステート（tfstate）の保存先設定 |
| `outputs.tf` | 他から参照される出力値の定義 |

---

## 3. バージョン制約

### 3-1. Terraform本体のバージョン

`version.tf` に以下の形式で記載します。

```hcl
terraform {
  required_version = "~> 1.5"
}
```

### 3-2. バージョン制約の書き方：`~>` を使う（悲観的制約）

> **方針：`~>` を使用する（`>=` は使わない）**

| 書き方 | 意味 | 採用 |
|---|---|---|
| `~> 1.5` | `1.5` 以上 `2.0` 未満（マイナー・パッチ更新を許可） | ✅ 推奨 |
| `~> 1.5.0` | `1.5.0` 以上 `1.6.0` 未満（パッチ更新のみ許可） | ✅ 推奨 |
| `>= 1.5` | `1.5` 以上すべて（メジャーバージョンアップも許可） | ❌ 非推奨 |

**理由：**  
Terraform公式は破壊的変更が起こりえない **悲観的制約（`~>`）** のみを設けることを推奨しています。  
`>=` を使うと将来のメジャーバージョンアップ時に予期しない破壊的変更が発生するリスクがあります。

> **参考：** メジャーバージョン（v1.x.x）だけ固定すれば破壊的変更は起きないため、積極的に新しいマイナーバージョンを採用してよいです。  
> Terraform公式サイトで配布されている最新バージョンを使うのが妥当です。

### 3-3. Providerのバージョン制約

CSPごとに **メジャーバージョンのみ統一** します（破壊的変更のみ許容しない）。

```hcl
# version.tf

terraform {
  required_version = "~> 1.5"

  required_providers {
    # AWSの例
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"   # メジャーバージョン5系に固定
    }
    # Azureの例
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}
```

**方針まとめ：**

| 対象 | 制約方針 |
|---|---|
| Terraform本体 | `~> X.Y`（マイナーまで固定） |
| Provider（CSPごと） | `~> X.0`（メジャーバージョンのみ統一） |

---

## 4. サンプルフォルダ構成

廉さんにサンプルのフォルダ構成を作成してもらう予定です。  
完成後、このドキュメントにリンクまたは内容を追記します。

> 📌 TODO：サンプルフォルダ構成の追記

---

## 5. 関連ドキュメント

- [terraform.md](./terraform.md) – モジュールの場所・呼び出しパターン
- [module-catalog.md](./module-catalog.md) – モジュール一覧
- [coding-standards.md](./coding-standards.md) – コーディング規約
