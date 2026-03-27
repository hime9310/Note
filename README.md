# EC2 スケジュール管理

AWS EventBridge Scheduler を使用して、EC2 インスタンスの起動・停止を自動化する Terraform プロジェクト。

## スケジュール一覧

| スケジュール名 | cron式 (JST) | 曜日 | アクション |
|---|---|---|---|
| ec2-weekday-start | `cron(0 9 ? * MON-FRI *)` | 月〜金 09:00 | EC2 起動 |
| ec2-weekday-stop | `cron(0 18 ? * MON-FRI *)` | 月〜金 18:00 | EC2 停止 |
| ec2-saturday-start | `cron(0 0 ? * SAT *)` | 土 00:00 | EC2 起動 |
| ec2-sunday-stop | `cron(0 19 ? * SUN *)` | 日 19:00 | EC2 停止 |

## 作成されるリソース

- IAM Role / Policy（EventBridge Scheduler 用）
- EventBridge Scheduler Schedule Group
- EventBridge Scheduler Schedule × 4

## 前提条件

- Terraform >= 1.10.0
- AWS Provider ~> 6.14.1
- 対象 EC2 インスタンスが存在すること
- AWS 認証情報が設定済みであること

## 変数

| 変数名 | 型 | 説明 |
|---|---|---|
| `aws_region` | `string` | AWS リージョン |
| `aws_account_id` | `string` | AWS アカウント ID |
| `instance_ids` | `list(string)` | スケジュール対象の EC2 インスタンス ID リスト（1つ以上必須） |

## 使い方

```bash
# 初期化
terraform init

# 実行計画の確認
terraform plan

# 適用
terraform apply

# 削除
terraform destroy
```

## ファイル構成

```
.
├── main.tf           # メインリソース定義（IAM, Schedule Group, Schedules）
├── variables.tf      # 変数定義
├── outputs.tf        # 出力定義
├── provider.tf       # プロバイダ設定
├── backend.tf        # バックエンド設定（ローカル）
├── version.tf        # バージョン制約
├── terraform.tfvars  # 変数値
└── README.md         # このファイル
```

## tfvars記述例
```bash

aws_region     = "ap-northeast-1"
aws_account_id = "1234567"
instance_ids = [
  "i-",
  "i-",
]
```
