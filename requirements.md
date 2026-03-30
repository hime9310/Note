# CSW（Cisco Secure Workload）検証環境 要件定義

## 概要

CSWエージェントの検証を目的とした、最小構成のAWS環境を構築する。
既存のTerraformモジュール（VPC / VPCエンドポイント / EC2）を使用すること。

---

## ネットワーク要件

### VPC

| 項目 | 値 |
|------|-----|
| CIDR | 10.0.0.0/16 |

### サブネット

| 項目 | 値 |
|------|-----|
| 種別 | プライベートサブネット |
| CIDR例 | 10.0.1.0/24 |
| アウトバウンド通信 | 必要（インターネットへの通常のアウトバウンド通信） |

### インターネット接続

- アウトバウンドのみ必要
- **NAT Gateway（NGW）を使用すること**
  - EC2起動停止によるIPアドレス変更の影響を避けるため
  - NGWにElastic IPを付与し、アウトバウンドの送信元IPを固定する
  - CSW SaaS側でのIPホワイトリスト管理・ログ追跡の観点からも安定性が高い
- EC2はプライベートサブネットに配置し、パブリックIPは付与しない

### アウトバウンド通信要件

| 項目 | 値 |
|------|-----|
| プロトコル | HTTPS（443） |
| 方向 | サーバー側からCSW SaaSへの一方向のみ |
| 送信元IP | NGWのElastic IP（固定） |

---

## セキュリティグループ要件

| 方向 | 要件 |
|------|------|
| インバウンド | **不要**（SSM Session Manager接続のためポート開放不要） |
| アウトバウンド | 全許可（CSWエージェント通信・SSM通信用） |

> SSH（22）/ RDP（3389）のインバウンド開放は不要。サーバー管理はSSM Session Manager経由で行う。

---

## VPCエンドポイント要件

SSM Session Manager接続に必要な以下2つのInterfaceエンドポイントを作成する。

| エンドポイント名 | 用途 | 型 |
|------|------|------|
| com.amazonaws.ap-northeast-1.ssm | SSMサービス本体 | Interface |
| com.amazonaws.ap-northeast-1.ssmmessages | Session Manager通信 | Interface |

---

## EC2要件

### Linuxサーバー

| 項目 | 値 |
|------|-----|
| インスタンスタイプ | t3.medium |
| vCPU | 2 |
| メモリ | 4GB |
| OS | Amazon Linux 2023 または Ubuntu 22.04 LTS |
| ストレージ | 30GB（gp3） |
| プライベートIP例 | 10.0.1.10 |
| IAMロール | SSM |
| キーペア | 不要（SSM接続のため） |

### Windowsサーバー

| 項目 | 値 |
|------|-----|
| インスタンスタイプ | t3.medium |
| vCPU | 2 |
| メモリ | 4GB |
| OS | Windows Server 2022 |
| ストレージ | 60GB（gp3） |
| プライベートIP例 | 10.0.1.11 |
| IAMロール | SSM |
| キーペア | 不要（SSM接続のため） |

---

## 構築完了後のアウトバウンド通信テスト

構築完了後、CSWエージェントインストール前に以下の疎通確認を実施すること。

### Linuxサーバー

**1. curlで443疎通確認（推奨）**
```bash
curl -v https://<CSW SaaSのFQDN> --max-time 10
```
> HTTPステータスが返れば（401/403含む）ネットワーク的にはOK

**2. ncでポート確認**
```bash
nc -zv <CSW SaaSのFQDN> 443
```

**3. opensslでTLS確認**
```bash
openssl s_client -connect <CSW SaaSのFQDN>:443
```

### Windowsサーバー

**PowerShellで443疎通確認**
```powershell
Test-NetConnection -ComputerName <CSW SaaSのFQDN> -Port 443
```
> `TcpTestSucceeded : True` であればOK

### テスト失敗時の確認ポイント

| 事象 | 確認箇所 |
|------|------|
| タイムアウト | SecurityGroupのアウトバウンドルール / NGWの設定 |
| DNS解決失敗 | VPCのenableDnsSupport設定 |
| 接続拒否 | CSW SaaS側のFQDN・ポート番号を確認 |

---

## 使用モジュール

以下の既存モジュールを使用すること。

- `modules/vpc` — VPCおよびサブネット構成
- `modules/vpc_endpoint` — VPCエンドポイント構成
- `modules/ec2` — EC2インスタンス構成

---

## 補足・制約事項

- 本環境はCSWエージェント検証専用の一時的な環境である
- CSWエージェントはアウトバウンド通信のみでCSWクラスタと通信するため、インバウンド通信は不要
- コスト最小化のため、不要なリソース（キーペア等）は作成しない
- 検証完了後はリソースを削除すること
