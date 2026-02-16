# Terraform MCP Server 構築 — AWS リソース一覧

> 構成図に基づくリソース一覧（DCS Hub AWS Tokyo Region）

---

## リソース一覧（全11リソース）

| # | カテゴリ | リソース種別 | リソース名（例） | 配置先 | 備考 |
|---|---|---|---|---|---|
| 1 | **ネットワーク** | VPC Subnet | PrivateSubnet1-1a | ap-northeast-1a | ECS + ALB 配置。既存サブネットを使用 |
| 2 | **ネットワーク** | VPC Subnet | PrivateSubnet1-1c | ap-northeast-1c | ALB 用2つ目。サブネットのみ作成、VPC Endpoint は設定しない |
| 3 | **ネットワーク** | Security Group | mcp-alb-sg | VPC | Inbound: HTTPS 443 from 社内NW CIDR |
| 4 | **ネットワーク** | Security Group | mcp-ecs-sg | VPC | Inbound: TCP 8080 from mcp-alb-sg のみ |
| 5 | **ロードバランサ** | ALB | mcp-server-alb | PrivateSubnet1-1a, 1c | scheme: internal（内部LB） |
| 6 | **ロードバランサ** | Target Group | mcp-server-tg | VPC | target-type: ip, port: 8080, health-check: /mcp |
| 7 | **ロードバランサ** | ALB Listener | — | ALB | HTTPS :443 → Target Group 転送 |
| 8 | **証明書** | ACM Certificate | — | ALB に紐付け | 社内CA / Venafi 連携 or ACM 発行 |
| 9 | **コンピュート** | ECS Cluster | terraform-mcp-cluster | — | キャパシティプロバイダ: FARGATE |
| 10 | **コンピュート** | ECS Service | terraform-mcp-service | PrivateSubnet1-1a | desired_count: 2, launch_type: FARGATE |
| 11 | **コンピュート** | ECS Task Definition | terraform-mcp-server | — | CPU: 512, Memory: 1024, image: hashicorp/terraform-mcp-server |
| 12 | **IAM** | IAM Role (実行) | mcp-server-execution-role | — | ECR pull + CloudWatch Logs 書き込み |
| 13 | **IAM** | IAM Role (タスク) | mcp-server-task-role | — | Terraform 操作対象への権限 + State アクセス |
| 14 | **監視** | CloudWatch Log Group | /ecs/terraform-mcp-server | — | 保持期間: 90日 |
| 15 | **State管理** | S3 Bucket | (チーム名)-terraform-state | — | 【未決定】推奨: S3 + DynamoDB |
| 16 | **State管理** | DynamoDB Table | terraform-state-lock | — | 【未決定】State Lock 用 |

> ※ #15, #16 は State 管理方式の確定後に作成

---

## 通信フロー

```
社内PC (Kiro IDE / VS Code)
  │
  │ port 80
  ▼
DCS Hub Shared Service (Tokyo Region)
  │
  │ Direct Connect
  ▼
ALB (mcp-server-alb) ← internal / HTTPS :443 / SSL証明書
  │
  │ HTTP :8080
  ▼
ECS Fargate Task (terraform-mcp-server)
  │ StreamableHTTP /mcp endpoint
  │
  ├──→ S3 + DynamoDB (State 管理)
  ├──→ 操作対象 AWS リソース (同一アカウント or Spoke Account)
  └──→ CloudWatch Logs (監査ログ)
```

---

## セキュリティグループ詳細

### mcp-alb-sg（ALB 用）

| 方向 | プロトコル | ポート | ソース/宛先 | 説明 |
|---|---|---|---|---|
| Inbound | TCP | 443 | 社内NW CIDR | Kiro IDE / VS Code からの HTTPS |
| Outbound | TCP | 8080 | mcp-ecs-sg | Target Group への転送 |

### mcp-ecs-sg（ECS タスク用）

| 方向 | プロトコル | ポート | ソース/宛先 | 説明 |
|---|---|---|---|---|
| Inbound | TCP | 8080 | mcp-alb-sg | ALB からの MCP トラフィック |
| Outbound | TCP | 443 | 0.0.0.0/0 | Terraform Registry API / AWS API 呼び出し |

---

## サブネット構成の注意点

- **PrivateSubnet1-1a**: メインのサブネット。ECS タスクと ALB の両方を配置
- **PrivateSubnet1-1c**: ALB 作成の AWS 要件（2 AZ 以上のサブネット）を満たすために作成。VPC Endpoint は設定しない（コスト最適化）
- ECS タスクは 1a のみに配置（1c にはタスクを配置しない構成も可。Service の subnets に 1a のみ指定）

---

## 構成図での命名規則（提案）

| リソース | 命名規則 | 例 |
|---|---|---|
| ECS Cluster | {チーム名}-mcp-cluster | infra-mcp-cluster |
| ECS Service | {チーム名}-mcp-service | infra-mcp-service |
| ALB | {チーム名}-mcp-alb | infra-mcp-alb |
| Target Group | {チーム名}-mcp-tg | infra-mcp-tg |
| Security Group | {チーム名}-{用途}-sg | infra-alb-sg / infra-ecs-sg |
| IAM Role | {チーム名}-mcp-{役割}-role | infra-mcp-task-role |
| Log Group | /ecs/{チーム名}-mcp-server | /ecs/infra-mcp-server |
