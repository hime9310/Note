---
name: terraform-code
description: Terraformコード生成スキル。モジュール構成・相対パス・呼び出しパターン・環境タイプ別ルールを提供する。
---
# Terraform モジュール利用ガイド

Kiro向けに、このワークスペースにおけるTerraformモジュールの場所・呼び出しパターンを説明するドキュメントです。
モジュールの詳細（全 inputs/outputs）は各リポジトリの `README.md` および `USAGE.md` を確認すること。

---

## 1. ディレクトリ構成

```
EngRepos/AWS/
├── aws-module-catalog.md                      # モジュール選定カタログ（Kiro参照元）
├── cms-aws-terraform-architecture/            # ルートモジュール（パターン実装）
│   ├── EC2/
│   ├── Fargate/
│   ├── Batch/
│   ├── SageMaker/
│   ├── SimpleWeb/
│   ├── SPA/
│   └── CodePipeline/
├── cms-aws-terraform-module-network/          # ネットワーク系再利用モジュール
├── cms-aws-terraform-module-compute/          # コンピュート系再利用モジュール
├── cms-aws-terraform-module-db/               # DB・ストレージ系再利用モジュール
├── cms-aws-terraform-module-integration/      # 監視・通知・CI/CD系再利用モジュール
└── cms-aws-terraform-module-machinelearning/  # ML系再利用モジュール
```

---

## 2. コード出力フォルダ構成

環境数はインフラ構成シートのシート数に従う。各環境フォルダ配下に以下を作成すること。

```
src/{cloud}/{project}/
├── {env1}/                         # 例：staging
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── version.tf
│   ├── provider.tf
│   ├── {env1}.tfbackend            # 例：staging.tfbackend
│   ├── env/
│   │   └── {env1}.tfvars          # 例：staging.tfvars
│   └── certs/                      # ACM証明書格納フォルダ
│       ├── server.crt              # 証明書本体（実ファイルは別途配置）
│       ├── key.pem                 # 秘密鍵（実ファイルは別途配置）
│       └── ca.crt                  # 中間CA証明書（実ファイルは別途配置）
└── {env2}/                         # 例：production
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── version.tf
    ├── provider.tf
    ├── {env2}.tfbackend
    ├── env/
    │   └── {env2}.tfvars
    └── certs/
        ├── server.crt
        ├── key.pem
        └── ca.crt
```

> `certs/` フォルダは空フォルダとして作成し、実際の証明書ファイルは人間が別途配置すること。

---

## 3. backend ファイルの書き方

各環境フォルダに `{env}.tfbackend` ファイルを作成すること。

```hcl
# ローカルにtfstateファイルを保存する場合
path = "envs/{env}.terraform.tfstate"

# S3に保存する場合（必要に応じてコメントアウトを解除）
# bucket  = "your-terraform-state-bucket"
# key     = "{project}/{env}/terraform.tfstate"
# region  = "ap-northeast-1"
# encrypt = true
```

---

## 4. ACM証明書の参照方法

main.tf でACMモジュールを呼び出す場合、`certs/` フォルダ内の証明書ファイルを参照すること。

```hcl
module "acm" {
  source            = "../../../../EngRepos/AWS/cms-aws-terraform-module-network/ACM"
  name_prefix       = var.name_prefix
  env               = var.env
  certificate_body  = file("${path.module}/certs/server.crt")
  private_key       = file("${path.module}/certs/key.pem")
  certificate_chain = file("${path.module}/certs/ca.crt")
}
```

---

## 5. 環境タイプの判定

添付された基本設計書の「1.基本設計」シート先頭の記載を読み取ること。

```
本システムは DCS Hub環境 に構築を行う    → Hub環境ルールを適用
本システムは Disconnect環境 に構築を行う → Disconnect環境ルールを適用
```

---

## 6. 環境タイプ別の生成ルール

### DCS Hub環境の場合

**作成済み前提のため生成しないこと：**
- VPC・Subnet・RouteTable・InternetGateway 等のNWリソース全般
- EC2インスタンス

**生成すること：**
- 上記以外のリソース（S3・ALB・RDS・KMS・WAF・SNS・CWAlarm 等）
- 既存のVPC IDやSubnet IDは `variables.tf` で受け取る形にすること
- 既存EC2への参照が必要な場合は `data` ブロックを使用すること

```hcl
# 既存VPCの参照例
data "aws_vpc" "this" {
  id = var.vpc_id
}

# variables.tf での受け取り例
variable "vpc_id" {
  description = "既存VPCのID（Hub環境から提供）"
  type        = string
}
```

### Disconnect環境の場合

**VPCからすべて作成すること：**
- NWリソース（VPC・Subnet・RouteTable・VPCEndpoint 等）含めすべて生成
- module-catalog.md のパターンに従って全リソースを構成すること

---

## 7. モジュールの参照パス

**絶対パスは使用しない**（開発者ごとにローカルパスが異なるため）。
`src/{cloud}/{project}/{env}/main.tf` から見た**相対パス**でモジュールを参照する。

> 環境フォルダが1層増えたため、パスの起点は `../../../../` となる。

### カテゴリ別の参照先

| カテゴリ | 参照先（sourceの起点） |
|---|---|
| Network | `../../../../EngRepos/AWS/cms-aws-terraform-module-network/<ModuleName>` |
| Compute | `../../../../EngRepos/AWS/cms-aws-terraform-module-compute/<ModuleName>` |
| DB / Storage | `../../../../EngRepos/AWS/cms-aws-terraform-module-db/<ModuleName>` |
| Integration | `../../../../EngRepos/AWS/cms-aws-terraform-module-integration/<ModuleName>` |
| MachineLearning | `../../../../EngRepos/AWS/cms-aws-terraform-module-machinelearning/<ModuleName>` |

### 記述例

```hcl
module "kms" {
  source      = "../../../../EngRepos/AWS/cms-aws-terraform-module-network/KMS"
  alias       = "example-kms"
  description = "sample"
}

module "fargate_webapp" {
  source      = "../../../../EngRepos/AWS/cms-aws-terraform-module-compute/Fargate"
  name_prefix = var.name_prefix
  env         = var.env
}
```

---

## 8. モジュール呼び出しパターン

### パターン① EC2（Web/APP + Bastion + RDS）
```
VPC + EC2 + ALB + RDS-Common + RDS-Aurora-MySQL
+ VPCEndpoint + S3(ALB/WAF logs) + CWLogs + KMS + WAF + SNS + CWAlarm
```

### パターン② Fargate（ECS）
```
VPC + Fargate + ALB + NLB + VPCEndpoint + ECR + RDS-Common + RDS-Aurora-MySQL
+ S3 + CWLogs + KMS + WAF + SNS + CWAlarm
```

### パターン③ Batch
```
VPC + Batch + VPCEndpoint + ECR + S3 + CWLogs + KMS + SNS
```

### パターン④ SageMaker
```
VPC + SageMaker + VPCEndpoint + S3 + CWLogs + KMS
```

### パターン⑤ SimpleWeb（静的配信）
```
S3(Web) + S3(CloudFront logs) + S3(WAF logs)
+ CloudFront + ACM + WAF + KMS
```

### パターン⑥ SPA（フロント+API+バックエンド）
```
CloudFront + APIGateway + NLB + Fargate + EC2(Bastion) + RDS-Common + RDS-Aurora-MySQL
+ ACM + WAF + S3 + CWLogs + SNS + CWAlarm + KMS
```

### パターン⑦ CodePipeline（GitHub → EC2デプロイ）
```
CodePipeline + ALB + VPCEndpoint + ACM
+ S3(Artifacts/ALB logs) + SNS + CWAlarm
```

---

## 9. リソースブロック命名規則

特別な理由がない限りリソースブロック名は `this` を使用する。

```hcl
resource "aws_kms_key" "this" {
  description = var.description
  tags = {
    Name = "${var.alias}"
    Env  = var.env
  }
}
```

- `module` ブロック名は役割が分かる名称を使用
  （例：`rds_common`、`fargate_webapp`、`s3_bucket_for_waf_log`）
- 既存モジュールの入出力名に合わせて連携する
  （例：`module.nlb.nlb_arn` を APIGateway へ渡す）

---

## 10. モジュール参照ルール

### 原則（参照のみ）
- 既存モジュール（`cms-aws-terraform-module-*`）は**参照のみ**とし、直接変更しない
- 変更実装は、まずルートモジュール側での組み合わせ・入力値調整で対応する

### 既存モジュール変更が必要と判断した場合
変更を即実装せず、まず「変更提案」として以下を提示する：
1. 変更理由（どの要件を満たすためか）
2. 影響範囲（他パターン・他環境への影響）
3. 代替案（ルートモジュール対応で回避できないか）

変更実装はチーム内レビュー・合意後に行う。

### 個別要件対応
- 原則として既存モジュールは変更しない
- 当該案件固有の個別要件に対応する場合は、既存モジュールをコピーして対象PJ内でカスタマイズして使用する
- カスタマイズ利用時は、元モジュールとの差分と適用理由を記録すること

### 対応フロー
1. 既存モジュールを参照して実現可能か確認
2. 不足がある場合は変更提案を作成
3. チームレビューで方針決定
4. 承認後に本家モジュール改修、または一時的にローカルカスタマイズ