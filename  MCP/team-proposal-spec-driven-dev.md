# 仕様駆動開発 ツール選定・ローカルMCP導入提案

**作成日：2026年4月**  
**目的：チーム内報告・相談・提案**  
**対象：CMSチーム Engチーム**

---

## エグゼクティブサマリー

仕様駆動開発（Spec-Driven Development）の導入を前提として、以下2点を提案する。

1. **IDE選定：Kiro（第一候補）/ VS Code + GitHub Copilot（代替・並走）**
2. **ローカルMCPサーバー：Excel / PowerPoint の自動生成機能をローカルで構築**

いずれも**外部通信ゼロ・ローカル完結**の構成が可能であり、情報セキュリティ審査の観点からも合理的なアプローチである。

---

## 1. 前提：仕様駆動開発とは

仕様駆動開発（SDD: Spec-Driven Development）とは、AIに直接コードを書かせる「バイブコーディング」とは異なり、**実装の前に仕様書を生成・合意し、その仕様書に基づいてAIが実装する**開発スタイルである。

```
【バイブコーディング（従来）】
  プロンプト → AIがコードを生成 → レビュー（後付け）
  問題: AIが何を考えてどう実装したか不透明。保守困難。

【仕様駆動開発（SDD）】
  要件（Requirements.md）
    ↓ チームでレビュー・合意
  設計（Design.md）
    ↓ チームでレビュー・合意
  タスク（Tasks.md）
    ↓
  実装（コード生成）
  メリット: 仕様書が残る。新メンバーへの引き継ぎが楽。変更理由が追跡できる。
```

> AWS の調査によると、**計画フェーズ中に仕様を詰めることで、実装フェーズで発見した場合と比べて 5〜7倍の手直しコスト削減**が見込まれる。
> （出典：Kiro公式ドキュメント・Håkon Eriksen Drange 氏 技術記事より）

---

## 2. KiroのLLMバックエンドについて

**KiroのLLMバックエンドはデフォルトで Claude Sonnet（Anthropic製）**である。

- 開発元：Amazon Web Services（AWS）
- ベースIDE：Visual Studio Code の OSS基盤（Code OSS）
- AIモデル：**Anthropic Claude Sonnet 4**（デフォルト）
- 価格：Free（50 interactions/月）/ Pro $19/月

> *"Kiro is powered by Claude Sonnet from Anthropic rather than OpenAI's GPT models — which is notable given Amazon's substantial investment in Anthropic."*  
> — OpenAI Tools Hub レビュー（2026年）

つまり、Kiroを使っているときにコードやドキュメントを生成しているのは、実質的にClaudeである。

---

## 3. Kiro vs VS Code（GitHub Copilot）比較

**前提：両ツールとも仕様駆動開発は実現可能。**  
ただし、アプローチとサポートの深さが異なる。

### 3-1. 仕様駆動開発への対応

| 観点 | Kiro | VS Code + GitHub Copilot |
|------|------|--------------------------|
| 仕様駆動開発のサポート | **ネイティブ搭載**（Spec / Steering / Skills） | SpecKit等の外部ツールで後付け対応 |
| Spec生成フロー | Requirements → Design → Tasks が自動化 | プロンプトで手動誘導が必要 |
| Steering（常時コンテキスト） | .kiro/steering/ フォルダで管理・自動適用 | カスタム指示ファイルで部分的に対応 |
| Skills（再利用プロセス） | .kiro/skills/ フォルダで管理 | プロンプトテンプレートで代替 |
| Hooks（自動トリガー） | ファイル保存・コミット時に自動実行 | 非対応 |
| AWS統合 | **ネイティブ対応**（Lambda・S3・IAM自動認識） | MCP経由で手動設定が必要 |

### 3-2. MCP対応

| 観点 | Kiro | VS Code + GitHub Copilot |
|------|------|--------------------------|
| ローカルstdio型MCP | ✅ 対応 | ✅ 対応（Agent Modeのみ） |
| リモートHTTP/SSE型MCP | ✅ 対応 | ✅ 対応 |
| 設定ファイル | `.kiro/settings/mcp.json` | `.vscode/mcp.json` |
| MCPのキー名 | `mcpServers` | `servers`（**異なるので注意**） |

### 3-3. メリット・デメリット詳細

#### Kiro

**メリット：**
- 仕様駆動開発のワークフローがUIレベルでサポートされており、チームへの展開が容易
- Steering / Skills / Spec の3機能により、チーム共通ルールをAIに常時適用できる
- AWS環境との親和性が高い（IAM Policy Autopilot 等）
- LLMバックエンドがClaudeであるため、複雑な仕様への準拠精度が高い
- VS Code互換のため、既存の拡張機能・キーバインドがほぼそのまま使える

**デメリット：**
- **社内導入審査が必要**（新規ツールとしての審査・承認フロー）
- Free Tier は 50 interactions/月と少ない（チーム利用ではPro契約が必要）
- 現時点でパブリックプレビュー段階（一部機能が変更される可能性）
- 小さなタスク・バグ修正には仕様生成のオーバーヘッドが大きい
- Spec生成に30〜45秒かかるため、単純な作業には向かない

#### VS Code + GitHub Copilot

**メリット：**
- **既存ライセンスで即日利用開始可能**（新規審査不要）
- Agent Mode + MCP により、Kiroと同等の拡張性を持つ
- モデル選択の自由度が高い（GPT-4o / Claude / Gemini 等から選択可能）
- マルチモデル対応（用途に応じて使い分け）
- SpecKitやcc-sddなどのOSSツールでKiroスタイルの仕様駆動開発を後付け導入可能

**デメリット：**
- 仕様駆動開発のサポートが後付けであるため、ワークフローの徹底にチームの規律が必要
- Steering / Spec / Hooks に相当する機能をプロンプトやファイルで手動管理する必要あり
- AWS固有の統合はKiroほどシームレスではない
- MCP は Agent Mode 限定（Ask / Edit Modeでは使用不可）
- CopilotのデフォルトモデルはGPT-4o（Claude利用はプレミアムリクエスト消費）

### 3-4. 判断マトリックス

| 判断軸 | Kiro 有利 | VS Code 有利 |
|--------|----------|-------------|
| 仕様駆動開発の深さ | ✅ | |
| 審査・導入の速さ | | ✅ |
| AWS環境との統合 | ✅ | |
| コスト（既存ライセンス活用） | | ✅ |
| チーム共通ルールの強制力 | ✅ | |
| モデル選択の柔軟性 | | ✅ |
| 長期的な仕様書資産の蓄積 | ✅ | ✅（SpecKit活用時） |

### 3-5. 推奨アプローチ（2段階）

```
【フェーズ1】VS Code + GitHub Copilot で即日開始（審査待ち期間）
  ↓ ローカルMCPサーバー（Excel / PowerPoint）を構築
  ↓ SpecKit を導入してKiroスタイルの仕様駆動開発フローを確立
  ↓ チームのワークフローを整備・習熟

【フェーズ2】Kiro 承認後に移行
  ↓ フェーズ1で確立したワークフローをKiroのSpec/Steering/Skillsに移管
  ↓ ローカルMCPサーバーはそのままKiroに接続（設定ファイル変更のみ）
  ↓ Hooks による自動化を段階的に追加
```

---

## 4. ローカルExcel / PowerPoint MCPサーバーのメリット

### 4-1. 構成の特徴

```
IDE（Kiro / VS Code）
    ↕ stdin/stdout（プロセス間通信のみ）
ローカルMCPサーバー（Python）
    ↓ ファイル操作
.xlsx / .pptx（ローカル保存）

外部通信：ゼロ
審査対象：Python + pip 3パッケージのみ
```

### 4-2. 仕様駆動開発における価値

| 従来の課題 | ローカルMCPで解決できること |
|-----------|--------------------------|
| Spec.md を書いた後、別途Excelパラメータシートを手作業で作る | AIがSpec.mdを読んで自動的にExcelパラメータシートを生成 |
| 設計レビュー用PPTを毎回フォーマットから作る | 社内テンプレートを読み込んでAIがスライドを生成 |
| テスト仕様書のExcelをコピペで更新 | Specのタスク一覧からExcel単体テスト仕様書を自動生成 |
| RCA報告書の作成に時間がかかる | Markdown形式のRCA文書からPPT / Excelを自動変換 |

### 4-3. メリット詳細

**① 審査コストが低い**
- 外部API・クラウドサービス・ネットワーク接続が一切ない
- 「ローカルで動くPythonスクリプト」として説明できる
- 審査対象は Python本体 + pip 3パッケージ（mcp / openpyxl / python-pptx）のみ

**② 社内テンプレートに完全準拠**
- 既存の社内Excelテンプレート・PowerPointテンプレートをそのまま読み込んで活用
- テーマ・カラー・フォント・レイアウトが自動的に継承される
- 「フォーマットを覚えなくても社内標準の資料が出来る」状態になる

**③ Claudeと同等の資料作成能力をIDEに統合**
- 普段Claudeに頼んでいるExcel・PowerPoint作成が、KiroやVS Code上で直接できる
- Spec.md → Excel パラメータシート → PowerPoint 設計説明資料 の流れが1つのIDEで完結
- チームメンバーがAIを使えばClaudeと同品質の資料を誰でも生成できる

**④ データがローカルに留まる**
- 機密性の高いパラメータ値やインフラ設計情報が外部に送信されない
- セキュリティポリシー上の懸念を最小化

**⑤ 将来的な拡張が容易**
- 同じ構造でWord（python-docx）・CSV・Markdownの MCPも追加可能
- ECSへの移行も可能（ただし外部通信が発生するため別途審査が必要）

### 4-4. Claudeとの機能対応表

| Claudeができること | ローカルExcel MCPで実現 | ローカルPPTX MCPで実現 |
|------------------|--------------------|---------------------|
| Excelテーブル（スタイル付き） | `add_excel_table` | — |
| 棒グラフ・折れ線グラフ・円グラフ | `add_bar_chart` 等 | — |
| カラースケール・条件付き書式 | `add_color_scale` 等 | — |
| ヘッダー色・罫線・書式設定 | `apply_style_range` | `add_table` |
| ドロップダウンリスト | `add_dropdown_validation` | — |
| テンプレートから作成・書式維持 | `copy_template_to_output` | `create_presentation` |
| 発表者ノート付きスライド | — | `set_slide_notes` |
| 図形・矢印・コネクタ | — | `add_shape` / `add_connector` |

---

## 5. Kiro導入時のディレクトリ構成（案）

画像で示したチーム展開例をベースに、MCPサーバーを統合した構成案を以下に示す。

```
workspace/                              ← Kiro WorkSpace ルート
│
├── .kiro/                              ← Kiro設定（Git管理方針を要検討）
│   ├── settings/
│   │   └── mcp.json                   ← MCPサーバー設定（Excel・PowerPoint）
│   │
│   ├── steering/                       ★ 固定：チーム共通の「常識」
│   │   ├── tech.md                    ← 技術スタック・使用言語・フレームワーク規約
│   │   ├── naming.md                  ← 命名規則（リソース名・変数名・ファイル名）
│   │   ├── security.md                ← セキュリティ要件・禁止事項
│   │   ├── aws-policy.md              ← AWS利用ポリシー・タグ付けルール
│   │   ├── excel-workflow-guide.md    ← Excel MCP 作業ガイド（inclusion: auto）
│   │   └── pptx-workflow-guide.md     ← PowerPoint MCP 作業ガイド（inclusion: auto）
│   │
│   ├── skills/                         ★ 固定：再利用するフォーマット・手順
│   │   ├── design-doc/
│   │   │   ├── SKILL.md               ← 基本設計書作成スキル
│   │   │   └── references/
│   │   │       └── design-template.md ← 基本設計書のフォーマット例
│   │   ├── parameter-sheet/
│   │   │   ├── SKILL.md               ← パラメータシート作成スキル
│   │   │   └── references/
│   │   │       └── excel-guide.md     ← Excel MCP ツール利用ガイド
│   │   ├── unit-test-spec/
│   │   │   ├── SKILL.md               ← 単体テスト仕様書作成スキル
│   │   │   └── references/
│   │   ├── rca-report/
│   │   │   ├── SKILL.md               ← RCA報告書（Excel / PPT）作成スキル
│   │   │   └── references/
│   │   └── review-slide/
│   │       ├── SKILL.md               ← 設計レビュー資料作成スキル
│   │       └── references/
│   │
│   └── specs/                          ◆ PJ毎に作成（仕様駆動開発の中核）
│       ├── pj-aaa/                    ← PJ-AAAのSpec
│       │   ├── requirements.md        ← 機能要件・非機能要件
│       │   ├── design.md              ← 技術設計・アーキテクチャ
│       │   └── tasks.md               ← 実装タスク一覧・進捗管理
│       └── pj-bbb/                    ← PJ-BBBのSpec
│           ├── requirements.md
│           ├── design.md
│           └── tasks.md
│
├── mcp_servers/                        ★ 固定：ローカルMCPサーバー群
│   ├── excel/
│   │   ├── excel_mcp_server.py        ← Excel MCPサーバー本体
│   │   ├── requirements.txt
│   │   └── templates/                 ← 社内Excelテンプレート置き場
│   │       ├── parameter_sheet.xlsx
│   │       ├── unit_test_spec.xlsx
│   │       └── design_review.xlsx
│   └── pptx/
│       ├── pptx_mcp_server.py         ← PowerPoint MCPサーバー本体
│       ├── requirements.txt
│       └── templates/                 ← 社内PPTテンプレート置き場
│           └── company_template.pptx
│
├── repos/                              ★ 固定：既存リポジトリ（参照専用）
│   └── EngRepo/                       ← 既存インフラコードなど（clone）
│
├── output/                             ◆ 生成ファイル出力先（PJ毎に整理）
│   ├── pj-aaa/
│   │   ├── ec2_parameters_20260402.xlsx
│   │   └── design_review_20260402.pptx
│   └── pj-bbb/
│
└── .vscode/                            ← VS Code互換設定（Kiroでも使用）
    └── mcp.json                        ← ローカルMCP設定（Kiro用mcp.jsonと同内容）
```

### 各ディレクトリの役割まとめ

| ディレクトリ | 更新頻度 | Git管理 | 格納するもの |
|------------|---------|--------|------------|
| `.kiro/steering/` | 低（方針変更時のみ） | **要検討** | チーム共通ルール・技術ポリシー |
| `.kiro/skills/` | 中（フォーマット改善時） | **要検討** | 再利用可能な作業プロセス定義 |
| `.kiro/specs/` | 高（PJの進行に合わせて） | ✅ 推奨 | PJ毎の要件・設計・タスク |
| `mcp_servers/` | 低（機能追加時のみ） | ✅ 推奨 | ローカルMCPサーバーコード |
| `mcp_servers/*/templates/` | 低（テンプレ改訂時） | ✅ 推奨 | 社内Excelテンプレート等 |
| `repos/` | 低（参照のみ） | ❌ 対象外 | 既存リポのclone |
| `output/` | 高（随時生成） | ❌ 対象外 | 生成ファイル（.gitignore推奨） |

### .kiro/のGit管理について（要検討）

`.kiro/` フォルダをGit管理するかどうかはチームで方針を決める必要がある。

| 管理する場合のメリット | 管理しない場合のメリット |
|-------------------|-------------------|
| チーム全員が同じSteering/Skillsを使える | 個人の試行錯誤を自由にできる |
| 設定変更の履歴が残る | 機密設定を共有リポに入れずに済む |
| 新メンバーのオンボーディングが楽 | 設定の競合を避けられる |

**推奨案：** `specs/` と `mcp_servers/` はGit管理、`steering/` と `skills/` は別リポジトリ管理（チーム設定リポジトリとして分離）

---

## 6. 参考リンク一覧

### 公式ドキュメント

| タイトル | URL | 概要 |
|---------|-----|------|
| Kiro 公式 | https://kiro.dev/ | Kiro IDEのトップページ・Getting Started |
| Kiro Spec ドキュメント | https://kiro.dev/docs/specs/ | 仕様駆動開発のSpec機能詳細 |
| Kiro Steering ドキュメント | https://kiro.dev/docs/steering/ | Steeringの設定・インクルージョンモード |
| Kiro Skills ドキュメント | https://kiro.dev/docs/skills/ | Skillsのフォルダ構成・SKILL.md仕様 |
| Kiro Hooks ドキュメント | https://kiro.dev/docs/hooks/ | イベント駆動の自動化（Hooks） |
| Kiro MCP ドキュメント | https://kiro.dev/docs/mcp/ | MCPサーバーの設定方法 |
| AWS awslabs MCP サーバー集 | https://github.com/awslabs/mcp | AWS公式MCPサーバー（Terraform・CDK等） |

### GitHub Copilot / VS Code 公式

| タイトル | URL | 概要 |
|---------|-----|------|
| GitHub Blog：Agent Mode with MCP | https://github.blog/news-insights/product-news/github-copilot-agent-mode-activated/ | Copilot Agent Mode + MCP 正式ローンチ |
| VS Code Blog：Agent Mode紹介 | https://code.visualstudio.com/blogs/2025/02/24/introducing-copilot-agent-mode | Agent Mode の詳細説明 |
| VS Code Blog：MCP対応 | https://code.visualstudio.com/blogs/2025/04/07/agentMode | VS Code 1.99でのMCP対応 |
| GitHub Docs：Agent Mode + MCP | https://docs.github.com/en/copilot/tutorials/enhance-agent-mode-with-mcp | MCP活用ベストプラクティス |

### 仕様駆動開発ツール（OSS）

| タイトル | URL | 概要 |
|---------|-----|------|
| GitHub SpecKit | https://github.com/github/spec-kit | GitHubのOSS仕様駆動開発ツールキット |
| cc-sdd（Kiroスタイルをどこでも） | https://github.com/gotalab/cc-sdd | Copilot / Cursor等でKiroスタイルのSDD |
| Claude Kiro | https://angelsen.github.io/claude-kiro/ | Claude Code向けKiroスタイルSDD実装 |
| MCP公式（Model Context Protocol） | https://modelcontextprotocol.io/ | MCPプロトコルの公式仕様 |
| MCP Python SDK | https://github.com/modelcontextprotocol/python-sdk | Python製MCPサーバーの構築ライブラリ |

### 技術記事・解説

| タイトル | URL | 著者 / 媒体 | ポイント |
|---------|-----|------------|--------|
| Kiroレビュー（Claude Sonnetバックエンドの確認） | https://www.openaitoolshub.org/en/blog/kiro-review-amazon-ide | OpenAI Tools Hub | Kiroの詳細レビュー・チーム向けの価値 |
| Kiroを使った仕様駆動開発の実践 | https://hedrange.com/2025/08/11/how-to-use-kiro-for-ai-assisted-spec-driven-development/ | Håkon Eriksen Drange | Terraform + AWSでの実践例 |
| Kiro First Impressions（AWS Premier Partner） | https://caylent.com/blog/kiro-first-impressions | Caylent（AWS Premier Partner） | 数週間の実使用レポート |
| Kiro vs Claude Code 2026比較 | https://www.morphllm.com/comparisons/kiro-vs-claude-code | Morph | 両ツールの哲学・使い分け比較 |
| Kiro vs Copilot & Cursor 比較 | https://apidog.com/blog/amazons-kiro-dev-ai-coding-ide/ | Apidog Blog | API開発チーム向け比較分析 |
| 仕様駆動開発：Kiro・SpecKit・BMAD比較 | https://medium.com/@visrow/comprehensive-guide-to-spec-driven-development-kiro-github-spec-kit-and-bmad-method-5d28ff61b9b1 | Medium | 3ツールの徹底比較 |
| Stop Chatting, Start Specifying（Kiro実践） | https://dev.to/kirodotdev/stop-chatting-start-specifying-spec-driven-design-with-kiro-ide-3b3o | DEV Community | TDD + 仕様駆動開発の実例 |
| 仕様駆動開発はウォーターフォールの逆襲か？ | https://marmelab.com/blog/2025/11/12/spec-driven-development-waterfall-strikes-back.html | Marmelab | 批判的視点からのSDD分析（バランスある考察） |
| VS Code + Copilot 向けMCPサーバーベスト10（2026） | https://toolradar.com/blog/best-mcp-servers-vscode | Toolradar | VS Code MCP実装の詳細・設定方法 |

### MCP関連

| タイトル | URL | 概要 |
|---------|-----|------|
| openpyxl 公式ドキュメント | https://openpyxl.readthedocs.io/ | Python製ExcelライブラリAPI仕様 |
| python-pptx 公式ドキュメント | https://python-pptx.readthedocs.io/ | Python製PPTXライブラリAPI仕様 |

---

## 7. まとめと提案

### 短期アクション（即日〜）

1. **VS Code + GitHub Copilot（既存ライセンス）** で仕様駆動開発フローを試行開始
2. **ローカルExcel / PowerPoint MCPサーバー** の審査申請を開始（Python + pip 3パッケージ）
3. 仕様駆動開発のワークフロー（Spec → Design → Tasks）を1つのPJで実践

### 中期アクション（Kiro審査期間中）

4. VS Code上でspecフォルダ・steeringガイドを整備してKiro移行に備える
5. ローカルMCPサーバーのPoC（単体テスト仕様書・パラメータシートの自動生成）
6. チームへのデモ・フィードバック収集

### 長期アクション（Kiro承認後）

7. Kiro導入・`.kiro/` フォルダ構成をチームで整備
8. Skills に設計書・仕様書の生成プロセスを定義
9. Hooks による自動化（コミット時の仕様書更新など）を段階的に追加

---

*本ドキュメントは2026年4月時点の情報に基づく。Kiroはパブリックプレビュー段階のため、機能・料金は変更される可能性がある。*
