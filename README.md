# EC2 スケジュール管理

AWS EventBridge Scheduler を使用して、EC2 インスタンスの起動・停止を自動化する Terraform プロジェクト。

Linux インスタンスは平日＋土日、Windows インスタンスは平日のみのスケジュールで管理する。

## スケジュール一覧

| スケジュール名 | cron式 (JST) | 曜日 | アクション | 対象 |
|---|---|---|---|---|
| ec2-weekday-start | `cron(0 9 ? * MON-FRI *)` | 月〜金 09:00 | EC2 起動 | Linux + Windows |
| ec2-weekday-stop | `cron(0 18 ? * MON-FRI *)` | 月〜金 18:00 | EC2 停止 | Linux + Windows |
| ec2-saturday-start | `cron(0 0 ? * SAT *)` | 土 00:00 | EC2 起動 | Linux のみ |
| ec2-sunday-stop | `cron(0 19 ? * SUN *)` | 日 19:00 | EC2 停止 | Linux のみ |

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
| `linux_instance_ids` | `list(string)` | Linux EC2 インスタンス ID リスト（平日+土日対象、1つ以上必須） |
| `windows_instance_ids` | `list(string)` | Windows EC2 インスタンス ID リスト（平日のみ対象、1つ以上必須） |

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
```bash
aws_region     = "ap-northeast-1"
aws_account_id = "12344556667"
linux_instance_ids = [
  "i-1234567",
]
windows_instance_ids = [
  "1234567444",
]
```