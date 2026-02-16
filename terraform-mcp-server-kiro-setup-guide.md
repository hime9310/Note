# Terraform MCP Server on ECS Fargate 構築 & Kiro IDE 導入手順書

> **対象読者**: インフラチームメンバー  
> **最終更新**: 2026年2月  
> **ステータス**: ドラフト（State管理方式・操作対象は未決定のため選択肢を併記）

---

## 1. 概要

### 1.1 本手順書の目的

チーム内で Amazon Kiro IDE を導入し、Terraform の plan/apply を集中実行するための MCP（Model Context Protocol）サーバを構築する。本手順書では、MCP サーバの構築から ALB/NW 設定、Kiro IDE の接続設定までを網羅する。

### 1.2 構成の全体像

```
┌─────────────────────┐
│  Local PC (社内NW)   │
│                     │
│  ┌───────────────┐  │
│  │ Kiro IDE      │──┼──── port 443 (HTTPS) ────┐
│  │ / VS Code     │  │                          │
│  │ + Copilot     │  │                          │
│  └───────────────┘  │                          │
└─────────────────────┘                          │
                                                 │
        ┌──── Direct Connect (1Gbps) ────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────┐
│  DCS Hub (AWS) - Tokyo Region                           │
│  ┌───────────────────────────────────────────────────┐  │
│  │  VPC                                              │  │
│  │  ┌─────────┐     ┌──────────────────────────┐    │  │
│  │  │   ALB   │────▶│  ECS Fargate              │    │  │
│  │  │ :443    │     │  Terraform MCP Server     │    │  │
│  │  │         │     │  (StreamableHTTP :8080)   │    │  │
│  │  └─────────┘     └──────────────────────────┘    │  │
│  │                           │                       │  │
│  │                     IAM Task Role                 │  │
│  │                           │                       │  │
│  │                    ┌──────┴──────┐                │  │
│  │                    ▼             ▼                │  │
│  │              同一VPC内     Transit Gateway        │  │
│  │              リソース     → Spoke Account         │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 1.3 MCP サーバを ECS Fargate に置く理由

Terraform の plan/apply をローカル PC で個別に実行するのではなく、ECS Fargate 上に集中実行環境として配置する。これにより以下のメリットが得られる。

- **State の安全管理**: 複数メンバーの同時実行による state 競合を防止
- **クレデンシャルの集約**: 個人 PC に AWS アクセスキーを配布せず、ECS タスクロールで IAM 権限を管理
- **実行環境の統一**: Terraform バージョンやプロバイダバージョンの差異をなくし、再現性を確保
- **監査性の向上**: CloudWatch Logs で誰がいつ何を実行したかを追跡可能

### 1.4 使用するコンポーネント

| コンポーネント | バージョン / 詳細 |
|---|---|
| Terraform MCP Server | HashiCorp 公式（Docker イメージ: `hashicorp/terraform-mcp-server`） |
| トランスポート | StreamableHTTP（リモート/分散構成推奨） |
| ECS 起動タイプ | Fargate |
| ロードバランサ | ALB（Application Load Balancer） |
| リージョン | ap-northeast-1（Tokyo） |
| Kiro IDE | 最新版 |

---

## 2. 前提条件

### 2.1 AWS アカウント

- DCS Hub（AWS）アカウントへのアクセス権限
- ECS / ALB / IAM / CloudWatch Logs の作成権限
- ECR へのプッシュ権限（カスタムイメージを使用する場合）

### 2.2 ネットワーク

- 社内 PC から DCS Hub VPC への Direct Connect 経由の接続が確立済み
- VPC 内にプライベートサブネット（ECS 用）とパブリック or プライベートサブネット（ALB 用）が存在すること
- セキュリティグループ / NACL の変更権限

### 2.3 ローカル環境

- Docker Desktop（MCP サーバのローカルテスト用）
- AWS CLI v2 設定済み
- Kiro IDE インストール済み（https://kiro.dev からダウンロード）

---

## 3. Terraform State 管理方式の選定（未決定）

MCP サーバで Terraform の plan/apply を実行するにあたり、state の管理方式を決定する必要がある。以下に3つの選択肢を示す。

### 3.1 選択肢比較

| 項目 | S3 + DynamoDB | HCP Terraform (旧 Terraform Cloud) | Terraform Enterprise |
|---|---|---|---|
| **コスト** | S3/DynamoDB の利用料のみ（低コスト） | Free tier あり。Team & Governance は有料 | ライセンス費用が必要 |
| **State Lock** | DynamoDB による排他ロック | 組み込み済み | 組み込み済み |
| **セットアップ難易度** | S3 バケット + DynamoDB テーブル作成 | アカウント登録 + Workspace 設定 | 自社サーバへのインストール |
| **アクセス制御** | IAM ポリシーで制御 | チーム/ワークスペース単位 | RBAC + SSO 連携可能 |
| **閉域網対応** | VPC エンドポイントで完全閉域可 | インターネット接続が必要 | 閉域網に対応 |
| **MCP サーバとの相性** | タスクロールで直接アクセス | TFE_TOKEN 環境変数で認証 | TFE_TOKEN + TFE_HOSTNAME で認証 |

### 3.2 推奨

DCS Hub 環境で閉域網を重視する場合は **S3 + DynamoDB** が最もシンプル。ECS タスクロールに S3/DynamoDB へのアクセス権限を付与するだけで完結し、インターネット接続が不要。

S3 + DynamoDB を選択する場合の backend 設定例:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-team-terraform-state"
    key            = "project-name/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

---

## 4. MCP サーバで操作する対象の選定（未決定）

### 4.1 選択肢

| パターン | 説明 | IAM 設計 |
|---|---|---|
| **A: 同一 DCS Hub アカウント内** | MCP サーバと同じアカウント内のリソースのみ操作 | タスクロールに直接権限付与 |
| **B: Child Spoke Account** | Transit Gateway 経由で Spoke Account のリソースを操作 | タスクロールから Spoke Account の IAM ロールに AssumeRole |
| **C: 両方** | Hub 内リソース + Spoke Account リソースの両方 | A + B の組み合わせ |

### 4.2 パターン B/C の場合の AssumeRole 設定

MCP サーバのタスクロールから Spoke Account のリソースを操作する場合：

**Spoke Account 側（信頼ポリシー）:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::role/mcp-server-task-role"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:PrincipalTag/team": "infra-team"
        }
      }
    }
  ]
}
```

**Hub Account 側（タスクロールポリシー）:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::role/terraform-execution-role"
    }
  ]
}
```

---

## 5. MCP サーバ構築手順

### 5.1 Docker イメージの準備

HashiCorp 公式の Docker イメージをそのまま使用する。カスタム instructions が必要な場合は独自ビルドする。

**公式イメージをそのまま使用する場合（推奨）:**

```bash
# 動作確認（ローカル）
docker run -i --rm hashicorp/terraform-mcp-server
```

**カスタムイメージを作成する場合:**

社内の Terraform 運用ルールに合わせた instructions を組み込む場合は、リポジトリをクローンしてビルドする。

```bash
git clone https://github.com/hashicorp/terraform-mcp-server.git
cd terraform-mcp-server

# instructions のカスタマイズ
# cmd/terraform-mcp-server/instructions.md を編集

# ビルド
make docker-build

# ECR へのプッシュ
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com

docker tag terraform-mcp-server:dev \
  <ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com/terraform-mcp-server:latest

docker push \
  <ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com/terraform-mcp-server:latest
```

### 5.2 ECS クラスタの作成

```bash
aws ecs create-cluster \
  --cluster-name terraform-mcp-cluster \
  --capacity-providers FARGATE \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
  --region ap-northeast-1
```

### 5.3 IAM ロールの作成

**タスク実行ロール（ECS がコンテナを起動するためのロール）:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

**タスクロール（MCP サーバコンテナが AWS リソースを操作するためのロール）:**

> ⚠️ 下記は S3 + DynamoDB state 管理 + 同一アカウント操作の例。操作対象に応じて権限を調整すること。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-team-terraform-state",
        "arn:aws:s3:::your-team-terraform-state/*"
      ]
    },
    {
      "Sid": "TerraformStateLock",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:ap-northeast-1:<ACCOUNT_ID>:table/terraform-state-lock"
    },
    {
      "Sid": "TerraformResourceManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ecs:*",
        "iam:*",
        "s3:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "ap-northeast-1"
        }
      }
    }
  ]
}
```

> ⚠️ **重要**: `TerraformResourceManagement` の権限は、実際の運用では操作対象リソースに合わせて最小権限に絞ること。上記は例示目的のワイルドカード。

### 5.4 CloudWatch Logs グループの作成

```bash
aws logs create-log-group \
  --log-group-name /ecs/terraform-mcp-server \
  --region ap-northeast-1

# 保持期間の設定（例: 90日）
aws logs put-retention-policy \
  --log-group-name /ecs/terraform-mcp-server \
  --retention-in-days 90
```

### 5.5 タスク定義の作成

以下の JSON ファイルを `task-definition.json` として保存する。

```json
{
  "family": "terraform-mcp-server",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/mcp-server-execution-role",
  "taskRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/mcp-server-task-role",
  "containerDefinitions": [
    {
      "name": "terraform-mcp-server",
      "image": "hashicorp/terraform-mcp-server:latest",
      "essential": true,
      "command": [
        "streamable-http",
        "--transport-port", "8080",
        "--transport-host", "0.0.0.0",
        "--mcp-endpoint", "/mcp"
      ],
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "MCP_TRANSPORT",
          "value": "streamable-http"
        },
        {
          "name": "MCP_ALLOWED_ORIGINS",
          "value": ""
        },
        {
          "name": "MCP_STATELESS",
          "value": "true"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/terraform-mcp-server",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "wget -q -O /dev/null http://localhost:8080/mcp || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

**パラメータの説明:**

| パラメータ | 値 | 説明 |
|---|---|---|
| `cpu` / `memory` | 512 / 1024 | 小規模チーム向け。大規模な plan を実行する場合は 1024/2048 に増強 |
| `--transport-host` | 0.0.0.0 | ALB からの接続を受け付けるために全インターフェースでリッスン |
| `--transport-port` | 8080 | MCP サーバのリッスンポート |
| `--mcp-endpoint` | /mcp | MCP プロトコルのエンドポイントパス |
| `MCP_ALLOWED_ORIGINS` | （空文字列） | 社内 NW からのみアクセスのため。必要に応じて設定 |
| `MCP_STATELESS` | true | ALB 背後の複数タスクでロードバランスする場合に推奨 |

タスク定義の登録:

```bash
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json \
  --region ap-northeast-1
```

### 5.6 HCP Terraform / Terraform Enterprise 連携を使用する場合

State 管理に HCP Terraform や Terraform Enterprise を選択した場合は、`environment` に以下を追加する。機密情報は Secrets Manager から取得する構成を推奨。

```json
{
  "name": "TFE_TOKEN",
  "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:<ACCOUNT_ID>:secret:terraform/tfe-token"
},
{
  "name": "TFE_HOSTNAME",
  "value": "app.terraform.io"
}
```

> `valueFrom` を使用する場合は、タスク実行ロールに Secrets Manager の `GetSecretValue` 権限が必要。

---

## 6. ALB / ネットワーク設定

### 6.1 セキュリティグループの作成

**ALB 用セキュリティグループ:**

```bash
# ALB SG: 社内NWからのHTTPS接続のみ許可
aws ec2 create-security-group \
  --group-name mcp-alb-sg \
  --description "ALB for Terraform MCP Server" \
  --vpc-id <VPC_ID>

# Direct Connect 経由の社内NW CIDR からの HTTPS を許可
aws ec2 authorize-security-group-ingress \
  --group-id <ALB_SG_ID> \
  --protocol tcp \
  --port 443 \
  --cidr <ONPREM_CIDR>
```

**ECS タスク用セキュリティグループ:**

```bash
# ECS SG: ALB からのみ接続許可
aws ec2 create-security-group \
  --group-name mcp-ecs-sg \
  --description "ECS tasks for Terraform MCP Server" \
  --vpc-id <VPC_ID>

# ALB SG からの 8080 ポートのみ許可
aws ec2 authorize-security-group-ingress \
  --group-id <ECS_SG_ID> \
  --protocol tcp \
  --port 8080 \
  --source-group <ALB_SG_ID>
```

### 6.2 ALB の作成

```bash
# ALB の作成（内部ロードバランサ = 社内NWからのみアクセス可能）
aws elbv2 create-load-balancer \
  --name mcp-server-alb \
  --type application \
  --scheme internal \
  --subnets <PRIVATE_SUBNET_1> <PRIVATE_SUBNET_2> \
  --security-groups <ALB_SG_ID>
```

> **重要**: `--scheme internal` を指定して内部 ALB とすること。インターネットに公開しない。

### 6.3 ターゲットグループの作成

```bash
aws elbv2 create-target-group \
  --name mcp-server-tg \
  --protocol HTTP \
  --port 8080 \
  --vpc-id <VPC_ID> \
  --target-type ip \
  --health-check-path /mcp \
  --health-check-interval-seconds 30 \
  --healthy-threshold-count 3 \
  --unhealthy-threshold-count 3
```

> ターゲットタイプは `ip`（Fargate の awsvpc ネットワークモードに必須）。

### 6.4 リスナーの作成

**HTTPS（推奨）:**

```bash
aws elbv2 create-listener \
  --load-balancer-arn <ALB_ARN> \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=<ACM_CERT_ARN> \
  --default-actions Type=forward,TargetGroupArn=<TG_ARN>
```

> ACM 証明書は社内 CA またはAWS Certificate Manager で発行。Venafi 連携で自動更新する場合は既存の証明書管理フローに従う。

**HTTP（検証環境用）:**

```bash
aws elbv2 create-listener \
  --load-balancer-arn <ALB_ARN> \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=<TG_ARN>
```

> ⚠️ HTTP は検証目的のみ。本番環境では必ず HTTPS を使用すること。

### 6.5 ECS サービスの作成

```bash
aws ecs create-service \
  --cluster terraform-mcp-cluster \
  --service-name terraform-mcp-service \
  --task-definition terraform-mcp-server \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[<PRIVATE_SUBNET_1>,<PRIVATE_SUBNET_2>],
    securityGroups=[<ECS_SG_ID>],
    assignPublicIp=DISABLED
  }" \
  --load-balancers "targetGroupArn=<TG_ARN>,containerName=terraform-mcp-server,containerPort=8080" \
  --region ap-northeast-1
```

**パラメータの説明:**

| パラメータ | 値 | 説明 |
|---|---|---|
| `desired-count` | 2 | 可用性のため2タスク。検証時は1でも可 |
| `assignPublicIp` | DISABLED | プライベートサブネットで動作、パブリック IP 不要 |
| `containerPort` | 8080 | MCP サーバのリッスンポート |

### 6.6 ネットワーク経路の確認

構築完了後、以下の経路で通信が通ることを確認する。

```
社内PC → Direct Connect → DCS Hub VPC → ALB (:443) → ECS Fargate (:8080)
```

確認コマンド（社内 PC から実行）:

```bash
# ALB の DNS 名を取得
aws elbv2 describe-load-balancers \
  --names mcp-server-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text

# 疎通確認
curl -v https://<ALB_DNS_NAME>/mcp
```

期待されるレスポンス: HTTP 200 または MCP プロトコルのレスポンス。

---

## 7. Kiro IDE の接続設定

### 7.1 Kiro IDE のインストール

1. https://kiro.dev からインストーラをダウンロード
2. インストール後、初回起動時にアカウント設定を完了する

### 7.2 MCP サーバの接続設定（リモート接続）

ECS Fargate 上の MCP サーバに接続する場合は、リモート MCP サーバ（Streamable HTTP）として設定する。

**設定ファイルの場所:**

| スコープ | パス |
|---|---|
| ユーザー全体（全プロジェクト共通） | `~/.kiro/settings/mcp.json` |
| ワークスペース固有 | `.kiro/settings/mcp.json`（プロジェクトルート） |

> 両方に設定がある場合、ワークスペース設定が優先される。

**リモート MCP サーバ設定（`mcp.json`）:**

```json
{
  "mcpServers": {
    "terraform": {
      "url": "https://<ALB_DNS_NAME>/mcp",
      "headers": {
        "X-Team-Id": "infra-team"
      },
      "disabled": false,
      "autoApprove": [],
      "disabledTools": []
    }
  }
}
```

> **url**: ALB の DNS 名 + MCP エンドポイントパス（`/mcp`）を指定。社内 DNS でカスタムドメインを割り当てている場合はそのドメインを使用する。

### 7.3 接続の確認

1. Kiro IDE を起動
2. メニューから **Kiro → MCP Servers** を開く
3. `terraform` サーバが「Connected」と表示されることを確認
4. チャットインターフェースで以下を入力してテスト:

```
Terraform の AWS プロバイダについて教えてください
```

MCP サーバが正常に動作していれば、Terraform Registry から最新のプロバイダ情報を取得した回答が返る。

### 7.4 VS Code + GitHub Copilot での設定（補足）

VS Code + GitHub Copilot でも同じ MCP サーバを利用可能。`.vscode/mcp.json` に以下を追加する。

```json
{
  "servers": {
    "terraform": {
      "type": "http",
      "url": "https://<ALB_DNS_NAME>/mcp"
    }
  }
}
```

---

## 8. セキュリティに関する注意事項

### 8.1 MCP サーバのセキュリティ

HashiCorp の公式ドキュメントでは以下の点が強調されている。

- MCP サーバは Terraform のデータを MCP クライアントと LLM に公開する可能性がある。信頼できない MCP クライアントや LLM とは使用しないこと
- StreamableHTTP を使用する場合は `MCP_ALLOWED_ORIGINS` 環境変数を設定して信頼できるオリジンのみを許可すること
- MCP サーバの出力はクエリやモデルによって動的に変化する。実行前に必ず plan の内容をレビューすること

### 8.2 ネットワークセキュリティ

- ALB は `internal`（内部）スキームとし、インターネットに公開しない
- セキュリティグループで ALB への接続元を社内 NW CIDR に限定
- ECS タスクは ALB からの通信のみ受け付ける
- Direct Connect 経由の閉域通信を利用

### 8.3 IAM のベストプラクティス

- タスクロールは最小権限の原則に従う
- Terraform で操作するリソースの範囲を明確にし、それ以外のリソースへのアクセスは拒否
- Spoke Account への AssumeRole はタグベースの条件を付与して制限
- IAM ポリシーの変更はセキュリティチームの承認を経ること

### 8.4 TLS 設定

リモートデプロイでは TLS 証明書の設定が推奨される。ALB で TLS を終端する構成の場合、ALB ← クライアント間は HTTPS、ALB → ECS 間は HTTP（VPC内通信）となる。より厳密なセキュリティが必要な場合は ALB → ECS 間も HTTPS とする（MCP サーバの `--tls-cert` / `--tls-key` オプションを使用）。

---

## 9. 運用ガイド

### 9.1 ログの確認

```bash
# 直近のログを確認
aws logs tail /ecs/terraform-mcp-server --follow

# 特定時間帯のログを検索
aws logs filter-log-events \
  --log-group-name /ecs/terraform-mcp-server \
  --start-time <EPOCH_MS> \
  --end-time <EPOCH_MS>
```

### 9.2 スケーリング

チームメンバーの増加や同時利用数の増加に応じて、ECS サービスのタスク数を調整する。

```bash
# 手動スケーリング
aws ecs update-service \
  --cluster terraform-mcp-cluster \
  --service terraform-mcp-service \
  --desired-count 4

# Auto Scaling の設定（オプション）
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/terraform-mcp-cluster/terraform-mcp-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 \
  --max-capacity 8
```

### 9.3 MCP サーバのアップデート

```bash
# 新しいイメージでタスク定義を更新
aws ecs register-task-definition \
  --cli-input-json file://task-definition-v2.json

# サービスを更新（ローリングデプロイ）
aws ecs update-service \
  --cluster terraform-mcp-cluster \
  --service terraform-mcp-service \
  --task-definition terraform-mcp-server:<NEW_REVISION>
```

### 9.4 トラブルシューティング

| 症状 | 確認ポイント |
|---|---|
| Kiro から接続できない | ALB の DNS 名解決、セキュリティグループ、Direct Connect の疎通 |
| MCP サーバが起動しない | CloudWatch Logs でコンテナのエラーログ、タスク実行ロールの権限 |
| Terraform plan が失敗 | タスクロールの IAM 権限、Terraform プロバイダの設定、state バケットへのアクセス |
| ヘルスチェック失敗 | ターゲットグループのヘルスチェックパス（`/mcp`）、ECS タスクの起動状態 |
| タイムアウト | ALB のアイドルタイムアウト設定（デフォルト60秒）、大規模 plan の場合は延長 |

---

## 10. チーム展開チェックリスト

構築完了後、チームメンバーへの展開時に以下を確認する。

- [ ] Kiro IDE のインストール手順を共有
- [ ] `mcp.json` のテンプレートを共有（ALB の URL を含む）
- [ ] 社内 PC から ALB への疎通確認を各メンバーが実施
- [ ] MCP サーバ経由で `terraform plan` が正常に実行できることを確認
- [ ] Terraform の state 管理方式を確定し、backend 設定を統一
- [ ] 操作対象アカウント/リソースを確定し、IAM ポリシーを最終化
- [ ] セキュリティチームの承認を取得
- [ ] 運用ルール（誰がいつ apply できるか等）をドキュメント化

---

## 付録 A: awslabs 版 Terraform MCP Server について

HashiCorp 公式の `hashicorp/terraform-mcp-server` とは別に、AWS Labs が提供する `awslabs.terraform-mcp-server` も存在する。

| 項目 | HashiCorp 版 | awslabs 版 |
|---|---|---|
| **主な機能** | Registry 参照 + HCP/TFE Workspace 管理 + plan/apply | AWS ベストプラクティス + Checkov セキュリティスキャン |
| **Docker イメージ** | `hashicorp/terraform-mcp-server` | `mcp/aws-terraform` |
| **plan/apply 実行** | HCP/TFE ワークスペース経由で対応 | Terraform/Terragrunt コマンドを直接実行 |
| **セキュリティスキャン** | なし | Checkov 統合あり |
| **トランスポート** | Stdio / StreamableHTTP | Stdio |

チームの用途に応じて選択する。plan/apply の集中実行が目的の場合、awslabs 版は Terraform コマンドの直接実行をサポートしており、ECS 上でのリモート実行に適している可能性がある。両方を併用することも可能。

---

## 付録 B: 用語集

| 用語 | 説明 |
|---|---|
| MCP | Model Context Protocol。AI モデルと外部ツール/データソースを接続するオープンプロトコル |
| StreamableHTTP | MCP のトランスポートプロトコルの一つ。HTTP リクエストと SSE ストリームをサポート |
| stdio | 標準入出力。ローカル実行時の MCP トランスポート |
| DCS Hub | 社内 AWS 管理基盤のハブアカウント |
| Spoke Account | DCS Hub から Transit Gateway で接続された子アカウント |
| Kiro IDE | Amazon が提供する AI 開発環境。MCP クライアント機能を内蔵 |
| ALB | Application Load Balancer。HTTP/HTTPS トラフィックのロードバランシング |
| Fargate | サーバーレスコンテナ実行環境。EC2 インスタンスの管理が不要 |
