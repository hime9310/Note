# Terraform モジュール利用ガイド

Kiro向けに、このワークスペースにおけるTerraformモジュールの場所・呼び出しパターンを説明するドキュメントです。
モジュールの詳細（全 inputs/outputs）は各リポジトリの `README.md` および `USAGE.md` を確認すること。

---

## 1. ディレクトリ構成

### AWS

```
Eng-repos/AWSRepos/
├── aws-module-catalog.md                     # モジュール選定カタログ（Kiro参照元）
├── cms-aws-terraform-architecture/           # ルートモジュール（パターン実装）
│   ├── EC2/
│   ├── Fargate/
│   ├── Batch/
│   ├── SageMaker/
│   ├── SimpleWeb/
│   ├── SPA/
│   └── CodePipeline/
├── cms-aws-terraform-module-network/         # ネットワーク系
├── cms-aws-terraform-module-compute/         # コンピュート系
├── cms-aws-terraform-module-db/              # DB・ストレージ系
├── cms-aws-terraform-module-integration/     # 監視・通知・CI/CD系
└── cms-aws-terraform-module-machinelearning/ # ML系
```

### Azure
<!-- AWS検証完了後に追記 -->

### GCP
<!-- AWS検証完了後に追記 -->

---

## 2. モジュールの参照パス

**絶対パスは使用しない**（開発者ごとにローカルパスが異なるため）。
各ルートモジュールの `main.tf` から見た**相対パス**でモジュールを参照する。

### AWS

| カテゴリ | 参照先（sourceの起点） |
|---|---|
| Network | `../../cms-aws-terraform-module-network/<ModuleName>` |
| Compute | `../../cms-aws-terraform-module-compute/<ModuleName>` |
| DB / Storage | `../../cms-aws-terraform-module-db/<ModuleName>` |
| Integration | `../../cms-aws-terraform-module-integration/<ModuleName>` |
| MachineLearning | `../../cms-aws-terraform-module-machinelearning/<ModuleName>` |

```hcl
module "kms" {
  source      = "../../cms-aws-terraform-module-network/KMS"
  alias       = "example-kms"
  description = "sample"
}

module "fargate_webapp" {
  source      = "../../cms-aws-terraform-module-compute/Fargate"
  name_prefix = var.name_prefix
  env         = var.env
}
```

### Azure
<!-- AWS検証完了後に追記 -->

### GCP
<!-- AWS検証完了後に追記 -->

---

## 3. モジュール呼び出しパターン

### AWS

| パターン | 構成モジュール |
|---|---|
| ① EC2（Web/APP + Bastion + RDS） | VPC + EC2 + ALB + RDS-Common + RDS-Aurora-MySQL + VPCEndpoint + S3 + CWLogs + KMS + WAF + SNS + CWAlarm |
| ② Fargate（ECS） | VPC + Fargate + ALB + NLB + VPCEndpoint + ECR + RDS-Common + RDS-Aurora-MySQL + S3 + CWLogs + KMS + WAF + SNS + CWAlarm |
| ③ Batch | VPC + Batch + VPCEndpoint + ECR + S3 + CWLogs + KMS + SNS |
| ④ SageMaker | VPC + SageMaker + VPCEndpoint + S3 + CWLogs + KMS |
| ⑤ SimpleWeb（静的配信） | S3(Web/CF logs/WAF logs) + CloudFront + ACM + WAF + KMS |
| ⑥ SPA（フロント+API+バックエンド） | CloudFront + APIGateway + NLB + Fargate + EC2 + RDS-Common + RDS-Aurora-MySQL + ACM + WAF + S3 + CWLogs + SNS + CWAlarm + KMS |
| ⑦ CodePipeline（GitHub → EC2） | CodePipeline + ALB + VPCEndpoint + ACM + S3 + SNS + CWAlarm |

> **Batch**：Hub/Disconnected構成差分あり。ネットワーク基盤は外部で用意済み前提。
> **SageMaker**：AWS管理VPC / カスタマー管理VPC の両パターンに対応。
> **CodePipeline**：github connection status が AVAILABLE であることを前提に運用。

### Azure
<!-- AWS検証完了後に追記 -->

### GCP
<!-- AWS検証完了後に追記 -->

---

## 4. リソースブロック命名規則（CSP共通）

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

## 5. モジュール参照ルール（CSP共通）

### 原則（参照のみ）
- 既存モジュールは**参照のみ**とし、直接変更しない
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
