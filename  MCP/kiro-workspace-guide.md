# Kiro 導入ガイド：ワークスペース構成と運用方針

> 作成日：2026-04-07  
> 対象：社内Kiro導入チーム  
> 参照資料：仕様駆動開発におけるKiroの機能調査（Deloitte Tohmatsu Group, 2025）

---

## 目次

1. [機能概要（Steering / Spec / Skills）](#1-機能概要)
2. [全体フォルダ構成（ファイルツリー）](#2-全体フォルダ構成)
3. [Steering 詳細](#3-steering-詳細)
4. [Spec 詳細（フォルダ分けルール含む）](#4-spec-詳細)
5. [Skills 詳細（自動pull・Terraform参照含む）](#5-skills-詳細)
6. [Eng-repos（チームリポジトリ）との連携](#6-eng-reposチームリポジトリとの連携)
7. [各MDファイルの記述イメージ](#7-各mdファイルの記述イメージ)
8. [運用フロー早見表](#8-運用フロー早見表)

---

## 1. 機能概要

| 機能 | 役割 | 誰が定義 | いつ使われる |
|------|------|----------|-------------|
| **Steering** | チームのコーディング規約・プロジェクトルールをKiroに注入 | 人間 | 全フェーズにバックグラウンドで自動適用 |
| **Spec** | 要件→設計→タスク→実装の主軸フロー | Kiroが下書き→人間が承認 | 機能開発の都度、フェーズごとに進める |
| **Skills** | 再利用可能な手順書・ナレッジ | 人間 | チャットで `#スキル名` を打った時にオンデマンド |

### 基本原則
- **Steering と Skills は人間が定義**。Kiroは出力を生成しない
- **Spec は Kiroが下書き**し、人間がレビュー・承認してから次フェーズへ進む
- Kiroが勝手に先へ進むことはない

---

## 2. 全体フォルダ構成

```
workspace/                               # ローカルワークスペースルート
│
├── .kiro/                               # Kiro設定ディレクトリ
│   │
│   ├── steering/                        # 【Steering】全フェーズ自動適用ルール群
│   │   ├── coding-standards.md          # inclusion: auto  ← Engコーディング規約・テスト方針
│   │   ├── spec-structure-rules.md      # inclusion: auto  ← Specフォルダ命名規則（★重要）
│   │   ├── terraform-rules.md           # inclusion: fileMatch (**/*.tf) ← Terraform規約
│   │   ├── aws-policy.md                # inclusion: fileMatch (**/aws/**) ← AWSポリシー・命名規則
│   │   ├── azure-policy.md              # inclusion: fileMatch (**/azure/**) ← Azure規約
│   │   ├── gcp-policy.md                # inclusion: fileMatch (**/gcp/**) ← GCP規約
│   │   └── security-policy.md           # inclusion: auto  ← セキュリティ方針
│   │
│   ├── specs/                           # 【Spec】Kiroが自動生成・人間が承認
│   │   ├── aws/                         # クラウド別に分類
│   │   │   ├── ec2-scheduler/           # システム・サービス名
│   │   │   │   └── start-stop-schedule/ # 機能名（kebab-case）
│   │   │   │       ├── requirements.md  # Phase1: ユーザーストーリー・受け入れ基準
│   │   │   │       ├── design.md        # Phase2: アーキテクチャ・コンポーネント設計
│   │   │   │       └── tasks.md         # Phase3: チェックボックス付き実装タスクリスト
│   │   │   └── s3-lifecycle/
│   │   │       └── archive-policy/
│   │   │           ├── requirements.md
│   │   │           ├── design.md
│   │   │           └── tasks.md
│   │   ├── azure/
│   │   │   └── aks-cluster/
│   │   │       └── auto-scaling/
│   │   │           ├── requirements.md
│   │   │           ├── design.md
│   │   │           └── tasks.md
│   │   └── gcp/
│   │       └── gke-node/
│   │           └── node-pool-resize/
│   │               ├── requirements.md
│   │               ├── design.md
│   │               └── tasks.md
│   │
│   └── skills/                          # 【Skills】#スキル名 でオンデマンド呼び出し
│       │
│       ├── git-sync/                    # #git-sync ← 全Repoを一括pull
│       │   ├── git-sync.md              # メインスキル（手順定義）
│       │   └── references/
│       │       └── repo-list.md         # ★Repo一覧・ローカルパス・リモートURL定義
│       │
│       ├── git-sync-aws/                # #git-sync-aws ← AWSReposのみpull
│       │   └── git-sync-aws.md
│       │
│       ├── git-sync-azure/              # #git-sync-azure ← AzureReposのみpull
│       │   └── git-sync-azure.md
│       │
│       ├── git-sync-gcp/                # #git-sync-gcp ← GCPReposのみpull
│       │   └── git-sync-gcp.md
│       │
│       ├── terraform-patterns/          # #terraform ← Terraformモジュール参照ガイド
│       │   ├── terraform.md             # モジュールの場所・呼び出しパターンをKiroに説明
│       │   └── references/
│       │       └── module-catalog.md    # ★どのモジュールが何をするか一覧（本体はEngRepo）
│       │
│       ├── unit-test-spec/              # #unit-test ← テスト仕様書作成
│       │   ├── unit-test.md
│       │   └── references/
│       │       └── qa-template.md       # ★QA表テンプレート
│       │
│       ├── design-doc/                  # #design-doc ← 設計書生成
│       │   ├── design-doc.md
│       │   └── references/
│       │       └── design-template.md   # ★設計書テンプレート
│       │
│       └── drawio-diagram/              # #drawio ← draw.io連携（VS Code拡張）
│           └── drawio.md
│
├── Eng-repos/                           # 【チームリポジトリ clone】
│   │                                    # ※ git clone & git pull で最新化（Skills経由）
│   ├── AzureRepos/
│   │   ├── aaaaa/                       # Azure IaCリポジトリ
│   │   ├── bbbbb/
│   │   └── ccccc/
│   ├── AWSRepos/
│   │   ├── ddddd/                       # AWS IaCリポジトリ
│   │   ├── eeeee/
│   │   └── fffff/
│   └── GCPRepos/
│       ├── ggggg/                       # GCP IaCリポジトリ
│       └── hhhhh/
│
└── src/                                 # アプリケーションコード等
    └── ...
```

---

## 3. Steering 詳細

### 概要
Kiroとのすべてのやり取りにコンテキスト・指示を注入する仕組み。  
`.kiro/steering/` 配下の Markdown ファイルで定義し、**全て人間が作成・メンテナンス**する。

### 適用モード（inclusion）

| モード | 動作 | 用途例 |
|--------|------|--------|
| `auto` | すべてのやり取りに自動適用 | コーディング規約、セキュリティ方針 |
| `fileMatch` | 指定パターンのファイルがコンテキストに読み込まれた時のみ適用 | `*.tf` のみTerraform規約を適用 |
| `manual` | `#ファイル名` で明示指定した時のみ適用 | 大量ドキュメント等 |

### ファイル一覧と役割

| ファイル | inclusion | 内容 |
|----------|-----------|------|
| `coding-standards.md` | auto | 命名規則・コメント規約・テスト方針・PR規約 |
| `spec-structure-rules.md` | auto | **Specフォルダ命名規則（後述）** |
| `terraform-rules.md` | fileMatch (`**/*.tf`) | Terraformの記述規約・モジュール利用ルール |
| `aws-policy.md` | fileMatch (`**/aws/**`) | AWSリソース命名規則・タグ付けポリシー |
| `azure-policy.md` | fileMatch (`**/azure/**`) | Azure規約・命名規則 |
| `gcp-policy.md` | fileMatch (`**/gcp/**`) | GCP規約・命名規則 |
| `security-policy.md` | auto | 秘密情報の扱い・セキュリティチェック項目 |

---

## 4. Spec 詳細

### 概要
構造化された方法で機能の設計・実装を進める仕組み。  
各フェーズでKiroがドラフトを生成し、**人間がレビュー→承認してから次フェーズへ**進む。

### 仕様駆動開発フロー

```
人間：機能要望をKiroに自然言語で伝える
  ↓
Kiro：「Feature or Bugfix?」「Requirements-first or Design-first?」を確認
  ↓
Phase 1【要件定義】
  Kiro → requirements.md ドラフト生成（ユーザーストーリー・受け入れ基準）
  人間 → レビュー → 修正依頼 or 承認（承認まで反復）
  ↓
Phase 2【設計】
  Kiro → design.md ドラフト生成（アーキテクチャ・コンポーネント設計）
  人間 → レビュー → 修正依頼 or 承認（承認まで反復）
  ↓
Phase 3【タスク化】
  Kiro → tasks.md 生成（チェックボックス付き実装タスクリスト）
  人間 → レビュー・承認（承認まで反復）
  ↓
Phase 4【コード生成】
  Kiro → tasks.md のタスクを順番に実装（Steering + Spec の内容に基づきコード生成）
  人間 → 「タスク実行して」と指示 → 生成コードをレビュー・確認

成果物：コード / Terraform設定ファイル / 設計書 Markdown 等
```

### Spec フォルダ命名規則（★重要）

**`spec-structure-rules.md`（Steeringに配置）でKiroに強制する。**

```
specs/{cloud}/{system}/{feature-name}/
```

| 部分 | 値 | 例 |
|------|----|----|
| `{cloud}` | `aws` / `azure` / `gcp` / `common` | `aws` |
| `{system}` | システム・サービス名（kebab-case） | `ec2-scheduler` |
| `{feature-name}` | 機能名（kebab-case） | `start-stop-schedule` |

**例：**
```
specs/aws/ec2-scheduler/start-stop-schedule/
specs/azure/aks-cluster/auto-scaling/
specs/gcp/gke-node/node-pool-resize/
specs/common/auth/sso-integration/
```

#### Specフォルダ分けの2つの方法

**方法A（推奨）：Steeringで自動強制**  
`steering/spec-structure-rules.md` に命名規則を記述しておくと、  
Kiroが新しいSpecを作る際に自動的にその構造を使う。

**方法B：プロンプトで都度指示**
```
「AWSのEC2スケジューラーの起動停止機能を作りたい。
 Specは specs/aws/ec2-scheduler/start-stop/ に作成して」
```

### 各フェーズのファイル

| ファイル | フェーズ | 格納内容 |
|----------|---------|----------|
| `requirements.md` | Phase 1 | ユーザーストーリー、受け入れ基準、制約条件 |
| `design.md` | Phase 2 | アーキテクチャ図、コンポーネント設計、データモデル、Correctness Properties |
| `tasks.md` | Phase 3 | チェックボックス付き実装タスクリスト |

> **補足：** Spec内で `#[[file:openapi.yaml]]` のように外部ファイルを参照可能。  
> 既存の仕様書・テンプレート・モジュール等を活用できる。

---

## 5. Skills 詳細

### 概要
Kiroが特定タスクを実行する際に参照する、再利用可能な手順書・ナレッジ。  
チャットで `#スキル名` を指定して呼び出す。**Specとは独立して利用できる**。

### 格納場所

| レベル | パス | 用途 |
|--------|------|------|
| ワークスペースレベル | `.kiro/skills/` | プロジェクト固有のスキル。Git管理してチームで共有 |
| ユーザーレベル | `~/.kiro/skills/` | 個人使いのスキル |

### スキル一覧と呼び出し方

| チャット入力 | スキルファイル | 動作 |
|-------------|---------------|------|
| `#git-sync` | `git-sync/git-sync.md` | 全Repo（Azure・AWS・GCP）を一括pull |
| `#git-sync-aws` | `git-sync-aws/git-sync-aws.md` | AWSReposのみpull |
| `#git-sync-azure` | `git-sync-azure/git-sync-azure.md` | AzureReposのみpull |
| `#git-sync-gcp` | `git-sync-gcp/git-sync-gcp.md` | GCPReposのみpull |
| `#terraform` | `terraform-patterns/terraform.md` | Terraformモジュール参照ガイド |
| `#unit-test` | `unit-test-spec/unit-test.md` | テスト仕様書作成 |
| `#design-doc` | `design-doc/design-doc.md` | 設計書生成 |
| `#drawio` | `drawio-diagram/drawio.md` | draw.io操作手順（VS Code拡張） |

### Terraform Skills の考え方（★重要）

Skills の `terraform-patterns/` に格納するのは **モジュール本体ではない**。

| 場所 | 内容 | 役割 |
|------|------|------|
| `Eng-repos/AWSRepos/xxx/modules/` | モジュール本体コード | 実際のIaC（正） |
| `skills/terraform-patterns/terraform.md` | モジュールの**場所・呼び出し方**をKiroに説明 | 地図・索引 |
| `skills/terraform-patterns/references/module-catalog.md` | モジュール一覧（何がどこにあるか） | カタログ |

> **一言で言うと：SkillsのTerraformフォルダは「地図と索引」、実物はEngRepoにある**

---

## 6. Eng-repos（チームリポジトリ）との連携

### 基本方針

```
workspace/
└── Eng-repos/          ← ここにチームの各リポジトリをclone
    ├── AzureRepos/
    ├── AWSRepos/
    └── GCPRepos/
```

- リポジトリは `workspace/Eng-repos/` 配下に `git clone` する
- 最新化は **Skills経由でKiroに指示する**（手動 or `#git-sync` 呼び出し）
- 完全自動pull（定期実行）はKiro外（OS cron / CI等）で対応

### 自動pullの3パターン

| パターン | 方法 | メリット | 注意 |
|---------|------|---------|------|
| **Skills経由（推奨）** | `#git-sync` でKiroに指示 | 作業開始前に確実に最新化できる | 手動トリガーが必要 |
| **OS cron** | cronで定期的に `git pull` を実行 | 完全自動 | コンフリクト時に気づきにくい |
| **VS Code Task** | workspace設定にgit pullタスクを定義 | VS Code起動時に実行可能 | VS Codeに依存 |

---

## 7. 各MDファイルの記述イメージ

### steering/spec-structure-rules.md
```markdown
---
inclusion: auto
---

# Spec フォルダ命名規則

Specを作成する際は必ず以下の構造に従うこと。

## フォルダ構造
specs/{cloud}/{system}/{feature-name}/

- {cloud}        : aws / azure / gcp / common
- {system}       : システム・サービス名（kebab-case）
- {feature-name} : 機能名（kebab-case）

## 例
specs/aws/ec2-scheduler/start-stop-schedule/
specs/azure/aks-cluster/auto-scaling/
specs/gcp/gke-node/node-pool-resize/
specs/common/auth/sso-integration/

## 各フェーズのファイル
- requirements.md : Phase1 ユーザーストーリー・受け入れ基準
- design.md       : Phase2 アーキテクチャ・コンポーネント設計
- tasks.md        : Phase3 チェックボックス付き実装タスクリスト
```

---

### steering/coding-standards.md
```markdown
---
inclusion: auto
---

# Engチーム コーディング規約

## 命名規則
- 変数・関数: camelCase
- クラス: PascalCase
- 定数: UPPER_SNAKE_CASE
- ファイル名: kebab-case

## コメント規約
- 公開メソッドには必ずJSDoc/TSDoc形式のコメントを記述する
- TODO/FIXME コメントには担当者名と日付を記載する

## テスト方針
- ユニットテストカバレッジ 80% 以上を維持する
- テストファイルは {対象ファイル名}.test.ts の形式で作成する

## PR規約
- PRのタイトルは [feat/fix/chore]: 変更内容の形式で記述する
- 1PRあたりの変更は300行以内を目安とする
```

---

### steering/terraform-rules.md
```markdown
---
inclusion: fileMatch
fileMatchPattern: "**/*.tf"
---

# Terraform コーディング規約

## モジュール利用ルール
- 既存モジュールが存在する場合は必ずそれを利用する（独自実装禁止）
- モジュールの場所は skills/terraform-patterns/references/module-catalog.md を参照
- モジュールを直接コピー・改変しない。改変が必要な場合はチームに相談する

## 命名規則
- リソース名: {env}-{system}-{resource-type}（例: prod-ec2scheduler-lambda）
- 変数名: snake_case
- モジュール参照名: snake_case

## 必須タグ
すべてのリソースに以下のタグを付与すること：
- Project: {プロジェクト名}
- Environment: {dev/stg/prod}
- ManagedBy: terraform
- Owner: {チーム名}

## ファイル構成
main.tf       / variables.tf / outputs.tf / versions.tf
```

---

### skills/git-sync/references/repo-list.md
```markdown
# 管理対象リポジトリ一覧

※ このファイルを編集してRepoを追加・削除する

## Azure Repos
| 名前    | ローカルパス                       | リモートURL                          | メインブランチ |
|---------|------------------------------------|--------------------------------------|----------------|
| aaaaa   | Eng-repos/AzureRepos/aaaaa         | https://dev.azure.com/org/proj/aaaaa | main           |
| bbbbb   | Eng-repos/AzureRepos/bbbbb         | https://dev.azure.com/org/proj/bbbbb | main           |
| ccccc   | Eng-repos/AzureRepos/ccccc         | https://dev.azure.com/org/proj/ccccc | develop        |

## AWS Repos
| 名前    | ローカルパス                       | リモートURL                          | メインブランチ |
|---------|------------------------------------|--------------------------------------|----------------|
| ddddd   | Eng-repos/AWSRepos/ddddd           | https://github.com/org/ddddd         | main           |
| eeeee   | Eng-repos/AWSRepos/eeeee           | https://github.com/org/eeeee         | main           |
| fffff   | Eng-repos/AWSRepos/fffff           | https://github.com/org/fffff         | main           |

## GCP Repos
| 名前    | ローカルパス                       | リモートURL                          | メインブランチ |
|---------|------------------------------------|--------------------------------------|----------------|
| ggggg   | Eng-repos/GCPRepos/ggggg           | https://github.com/org/ggggg         | main           |
| hhhhh   | Eng-repos/GCPRepos/hhhhh           | https://github.com/org/hhhhh         | main           |
```

---

### skills/git-sync/git-sync.md
```markdown
# Git 全リポジトリ同期スキル

references/repo-list.md に記載された全リポジトリに対し、以下の手順でgit pullを実行する。

## 手順
1. references/repo-list.md を読み込み、対象リポジトリ一覧を確認する
2. 各リポジトリのローカルパスに移動し、`git pull origin {メインブランチ}` を実行する
3. コンフリクト・エラーが発生した場合はリポジトリ名とエラー内容を報告する
4. 全リポジトリ完了後、成功/失敗のサマリーを表示する

## 対象を絞る場合
- AWSのみ : #git-sync-aws
- Azureのみ: #git-sync-azure
- GCPのみ  : #git-sync-gcp
```

---

### skills/git-sync-aws/git-sync-aws.md
```markdown
# AWS リポジトリ同期スキル

../git-sync/references/repo-list.md の「AWS Repos」セクションのみを対象に
git pull を実行する。

## 手順
1. repo-list.md の AWS Repos セクションを読み込む
2. 各AWSリポジトリのローカルパスに移動し `git pull origin {メインブランチ}` を実行する
3. エラーがあればリポジトリ名とエラー内容を報告する
4. 完了後、成功/失敗のサマリーを表示する
```

---

### skills/terraform-patterns/references/module-catalog.md
```markdown
# Terraform モジュール カタログ

※ モジュール本体コードは Eng-repos 配下を参照すること。コピー・複製禁止。

## AWS モジュール（Eng-repos/AWSRepos/ddddd/modules/）
| モジュール名    | 相対パス                               | 用途                    |
|----------------|----------------------------------------|-------------------------|
| ec2            | ../../Eng-repos/AWSRepos/ddddd/modules/ec2   | EC2インスタンス作成 |
| vpc            | ../../Eng-repos/AWSRepos/ddddd/modules/vpc   | VPCネットワーク構成 |
| s3-bucket      | ../../Eng-repos/AWSRepos/ddddd/modules/s3   | S3バケット作成      |
| lambda         | ../../Eng-repos/AWSRepos/ddddd/modules/lambda | Lambda関数作成    |
| rds            | ../../Eng-repos/AWSRepos/eeeee/modules/rds   | RDSインスタンス作成 |

## Azure モジュール（Eng-repos/AzureRepos/aaaaa/modules/）
| モジュール名    | 相対パス                                      | 用途              |
|----------------|-----------------------------------------------|-------------------|
| aks            | ../../Eng-repos/AzureRepos/aaaaa/modules/aks  | AKSクラスター作成 |
| vnet           | ../../Eng-repos/AzureRepos/aaaaa/modules/vnet | VNet構成          |
| storage        | ../../Eng-repos/AzureRepos/bbbbb/modules/storage | Storageアカウント |

## GCP モジュール（Eng-repos/GCPRepos/ggggg/modules/）
| モジュール名    | 相対パス                                      | 用途              |
|----------------|-----------------------------------------------|-------------------|
| gke            | ../../Eng-repos/GCPRepos/ggggg/modules/gke    | GKEクラスター作成 |
| gcs            | ../../Eng-repos/GCPRepos/ggggg/modules/gcs    | GCSバケット作成   |

## モジュール呼び出し例（AWS EC2）
module "ec2_instance" {
  source        = "../../Eng-repos/AWSRepos/ddddd/modules/ec2"
  instance_type = "t3.micro"
  ami_id        = "ami-xxxxxxxxxx"
  tags          = local.common_tags
}
```

---

### skills/terraform-patterns/terraform.md
```markdown
# Terraform モジュール参照ガイド

Terraformコードを書く際は以下のルールに従うこと。

## 基本ルール
1. モジュールの一覧は references/module-catalog.md を必ず確認する
2. 既存モジュールが存在する場合は必ずそれを利用する（独自実装禁止）
3. モジュール本体は Eng-repos 配下にある。コピー・改変禁止
4. パスは module-catalog.md に記載された相対パスを使用する

## 作業前の確認事項
- `#git-sync` を実行してモジュールが最新であることを確認する
- 使用するモジュールのバージョン・インターフェースを確認する

## 参照方法
module-catalog.md の「相対パス」列のパスを source に指定する。
詳細な使用例は module-catalog.md を参照。
```

---

## 8. 運用フロー早見表

### 作業開始前（毎回）
```
1. #git-sync        → 全Repoを最新化
   or
   #git-sync-aws    → AWS関連作業の場合
```

### 新機能開発
```
1. Kiroに自然言語で要望を伝える
   例：「AWSのEC2をスケジュールで起動停止する機能を作りたい。
        Specは specs/aws/ec2-scheduler/start-stop/ に作成して」

2. Phase1: requirements.md をKiroが生成 → レビュー・承認
3. Phase2: design.md をKiroが生成 → レビュー・承認
4. Phase3: tasks.md をKiroが生成 → レビュー・承認
5. Phase4: 「タスク実行して」→ コード生成 → レビュー・確認
```

### Terraformコード作成時
```
1. #git-sync-aws（or azure/gcp）→ モジュールを最新化
2. #terraform               → モジュールカタログを確認
3. Kiroにコード生成を依頼     → Steeringのterraform-rules.mdが自動適用
```

### スキル追加時
```
1. .kiro/skills/{スキル名}/ フォルダを作成
2. {スキル名}.md に手順を記述
3. 必要に応じて references/ 配下に参照資料を格納
4. チャットで #スキル名 を呼び出して動作確認
```

---

*© 2026 社内Kiro導入チーム*
