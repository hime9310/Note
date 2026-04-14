# Terraform モジュール利用ガイド

> Kiro（AIコーディングアシスタント）向けに、このリポジトリにおけるTerraformモジュールの場所・呼び出しパターンを説明するドキュメントです。

---

## 1. モジュールのディレクトリ構成

本リポジトリは **Terraform公式推奨のフォルダ構成** を採用しています。

```
(リポジトリルート)/
├── modules/               # 再利用可能なモジュール群
│   ├── compute/
│   │   └── main.tf
│   ├── database/
│   │   └── main.tf
│   └── network/
│       └── main.tf
├── prod/                  # 本番環境
│   ├── backend.tf
│   ├── main.tf
│   ├── provider.tf
│   ├── variables.tf
│   └── version.tf
└── staging/               # ステージング環境
    ├── backend.tf
    ├── main.tf
    ├── provider.tf
    ├── variables.tf
    └── version.tf
```

---

## 2. モジュールの場所について（ローカルパスの扱い）

> **重要：** 開発者ごとにリポジトリをcloneしたローカルパスは異なります（例：`C:\Users\yamada\repos\...` vs `C:\work\...`）。  
> そのため、モジュールの参照には **リポジトリルートからの相対パス** を使用します。  
> こうすることで、clone先がどこであっても同じコードが動作します。

### 相対パスによる参照（推奨）

呼び出し元（例：`prod/main.tf`）から見た相対パスでモジュールを指定します。

```hcl
# prod/main.tf

module "compute" {
  source = "../modules/compute"

  # 変数はここで渡す
  instance_type = var.instance_type
  subnet_id     = module.network.subnet_id
}

module "network" {
  source = "../modules/network"

  vpc_cidr = var.vpc_cidr
}

module "database" {
  source = "../modules/database"

  db_instance_class = var.db_instance_class
  subnet_ids        = module.network.subnet_ids
}
```

---

## 3. モジュール呼び出しパターン

### パターン① 基本呼び出し（単一リソース）

`count` や `for_each` を使わない最もシンプルな呼び出し方。

```hcl
module "network" {
  source = "../modules/network"

  vpc_cidr    = "10.0.0.0/16"
  region      = var.region
  environment = var.environment
}
```

### パターン② `for_each` を使った複数リソースの呼び出し

同じモジュールを複数の設定で繰り返す場合に使用します。

```hcl
# for_each はリソースブロック内の1行目に記述し、直後に空行を入れる（コーディング規約）
module "compute" {
  for_each = var.compute_configs

  source = "../modules/compute"

  instance_type = each.value.instance_type
  subnet_id     = each.value.subnet_id
  name          = each.key
}
```

### パターン③ 環境別変数ファイルを使った呼び出し

環境ごとに`variables.tf`で変数を定義し、`terraform.tfvars`で値を渡します。

```hcl
# prod/variables.tf
variable "instance_type" {
  description = "EC2インスタンスタイプ"
  type        = string
}

# prod/main.tf
module "compute" {
  source = "../modules/compute"

  instance_type = var.instance_type  # terraform.tfvars から注入
}
```

---

## 4. リソースブロック名の命名規則

Terraformのベストプラクティスに従い、特別な理由がない限りリソースブロック名には **`this`** を使用します。

```hcl
# modules/compute/main.tf

resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name        = var.name
    Environment = var.environment
  }
}
```

---

## 5. モジュール仕様書（README.md）の自動生成

各モジュールディレクトリには `README.md` を配置します。  
**terraform-docs** を使って、Input/Output/Requirementsを自動生成します。

```bash
# モジュールのREADME.mdを自動生成
terraform-docs markdown table ./modules/compute > ./modules/compute/README.md
```

> **注意：** `formatOnSave`（markdownの自動整形）は **オフ** にしてください。  
> terraform-docsで自動生成されたフォーマットが崩れ、毎回gitで差分が検出される原因となります。

---

## 6. Kiro への補足情報

| 項目 | 内容 |
|---|---|
| モジュールの参照方式 | リポジトリ内相対パス（`../modules/xxx`） |
| リソースブロック名 | 原則 `this` |
| 複数リソース展開 | `for_each` を優先（`count`は順序依存のリスクあり） |
| 空値の扱い | 空文字 `""` ではなく `null` を使用 |
| README自動生成 | terraform-docs を使用 |
