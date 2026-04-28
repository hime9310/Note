
```
以下のファイルツリーをHTML（黒背景）で視覚化してください。

【要件】
- フォント：モノスペース（JetBrains Mono推奨）
- 背景：#111418（ダーク）
- ツリーの線：背景と明確に区別できる明るめのグレー
- ファイル名と注釈は点線でつなぎ一行に収める
- 注釈は # コメント形式
- バッジを2種類付ける
  - スコープ：CSP共通（緑）/ 検証フェーズ（AWS）（青）
  - ステータス：DONE（緑）/ WIP（青）/ AUTO（紫）/ TBD（グレー）
- ホバーで行をハイライト
- 凡例を下部に配置

【ファイルツリー】
workspace/
├── .kiro/                                  # Kiro 設定ディレクトリ
│   │
│   ├── steering/                           # 全フェーズ自動適用ルール群
│   │   ├── coding-standards.md            # [CSP共通] 命名・コメント・コミット・fmt 規約
│   │   ├── terraform-rules.md             # [CSP共通] ディレクトリ構成・バージョン制約（CSP別含む）
│   │   ├── spec-structure-rules.md        # [CSP共通] Spec フォルダ命名・フェーズ・生成ルール
│   │   └── workflow.md                    # [CSP共通] 作業フロー・インプット参照先・出力先定義
│   │
│   ├── specs/                             # Kiro 自動生成・人間が承認
│   │   └── aws/
│   │       └── cms-kiro-test/             # [AWS] 案件フォルダ（inputs 配下と同名）
│   │           ├── requirements.md        # [AUTO] ユーザーストーリー・機能要件・受け入れ基準
│   │           ├── design.md              # [AUTO] アーキテクチャ・コンポーネント設計（MD形式）
│   │           └── tasks.md               # [AUTO] 実装タスクリスト（チェックボックス形式）
│   │
│   └── skills/                            # オンデマンド呼び出しスキル群
│       ├── terraform-code/                # Terraform コード生成スキル
│       │   ├── terraform.md              # [AWS] モジュール構成・相対パス・呼び出し7パターン
│       │   └── references/
│       │       └── aws-module-catalog.md # [AWS] モジュール一覧・依存関係・入出力定義
│       └── design-doc/                   # 設計書生成スキル
│           └── design-doc.md             # [CSP共通] Excel 参照・MD 出力手順・要確認マークルール
│
├── Eng-repos/                             # チームリポジトリ clone 先
│   └── AWSRepos/                          # [AWS] Skills 経由で git clone・最新化（検討中）
│       └── [既存 Terraform モジュール群]  # 相対パスで参照・直接変更禁止
│
└── inputs/                                # 案件インプット置き場（CSP 別）
    └── aws/
        └── cms-kiro-test/                 # [AWS] 案件フォルダ（specs・src 配下と同名）
            ├── QA.xlsx                    # 利用者との QA 票・要件・制約
            ├── parameter-sheet.xlsx       # パラメーターシート（案件ごとに検討）
            └── インフラ基本設計書.xlsx     # 設計書フォーマット・パラメーター値の元データ
```