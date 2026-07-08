# spec-driven-development

## 概要

DDDインフラ構築サービス向けの **仕様駆動開発** リポジトリです。Kiro を用いて、QA 票・基本設計書・構成図などのインプットから「要件定義 → 基本設計書 → Terraform コード」を半自動生成するための **共通設定（ルール・スキル）** と、参照用の既存 Terraform リポジトリ群（Git Submodule）を集約しています。

- チーム全員で同じ Kiro 設定を共有し、**個人のプロンプト作成力に依存しない**生成品質を実現する
- 各 CSP（`aws` / `azure` / `gcp`）の既存モジュールを Submodule として参照し、**成果物の品質を揃える**
- スキルは **コマンドで明示起動**（LLM によるパターン自動判定は行わない）し、動作の再現性を担保する

## ディレクトリ構成

```
spec-driven-development/
├── .kiro/               # Kiro 共通設定 ★Git 管理
│   ├── steering/        #   ルール群（コーディング規約・命名規約・環境定義・言語設定）
│   ├── skills/          #   生成スキル群（generate-design / generate-code / generate-diagram）
│   ├── settings/        #   MCP 設定テンプレート（mcp.example.json ※実動 mcp.json は各自作成）
│   └── agents/ hooks/   #   拡張用の予約枠（未導入）
├── EngRepos/            # 参照用の外部 Terraform リポジトリ群（Git Submodule）★Git 管理
├── Outputs/             # 案件ごとの成果物（要件・設計書・構成図・コード）🚫Git 管理外
├── AGENTS.md            # 生成 AI（Kiro）向けの目次
└── README.md            # 本ファイル
```

## 起動方法

本リポジトリを Kiro で開き、インプット（QA 票・基本設計書・構成図）を添付して、スキルを**スラッシュコマンドで明示起動**します。引数には `<案件フォルダ名>`（= 出力先 `Outputs/{cloud}/{project}/` の `{project}`）を渡します。

| やりたいこと | 起動コマンド | 出力先（`Outputs/{cloud}/{project}/` 配下） |
|---|---|---|
| 仕様書・設計書を作成（2 フェーズ） | `/generate-design <案件フォルダ名>` | `docs/requirements.md` → `docs/design.md` |
| Terraform コードを作成 | `/generate-code <案件フォルダ名>` | `code/{env}/` |
| 構成図を作成 | `/generate-diagram <案件フォルダ名>` | `docs/architecture.drawio` |

**起動例:**

```
（QA 票・基本設計書・構成図をそれぞれ添付してから）
/generate-design cms-aws-kiro-test
```

> 各フェーズは**人間のレビュー・承認後に次へ進みます**（設計書 → コードの連続実行はしません）。

## ドキュメント（詳細は OneNote で管理）

- 📖 [00 目次・はじめに](＜OneNoteページリンク＞)
- 📖 [01 環境仕様書（ディレクトリ構成・設計思想）](＜OneNoteページリンク＞)
- 📖 [02 導入手順書（初期セットアップ）](＜OneNoteページリンク＞)
- 📖 [03 利用手順書（開発の流れ）](＜OneNoteページリンク＞)
- 📖 [04 運用手順書（メンテナンス手順・トラブルシューティング）](＜OneNoteページリンク＞)
