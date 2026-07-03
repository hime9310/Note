# Specification-Driven Development 運用ガイド（改訂版）

本ドキュメントは、Kiro を用いた仕様駆動開発（設計書・Terraform コード・構成図の生成）を支える `.kiro/` 配下の**改訂後の構成**について、全体設計の考え方・ファイルごとの位置付け・メンテナンス手順をまとめた運用ガイドです。2026年7月のディレクトリ構成改善（チーム合意済み）を反映しています。

> **対象読者**: 本リポジトリで設計書・コードを生成するエンジニア、`.kiro/` の設定を保守するメンテナ、および本改訂の承認判断を行うリーダー層。
> **本ガイドの位置付け**: 上位者合意後、本ガイドの内容に沿ってリポジトリの本格修正を実施する。修正完了後は本ガイドが現行の運用ガイドとなる。

---

## 1. 結論（この改訂で何がどう変わるか）

**一言でいうと**: 「LLM の判断に依存する部分を減らし、人が明示的に指示する運用へ切り替える」ことで、**動作の安定性・クレジット効率・保守性**を同時に改善する。

### 変更サマリ（合意済み 6 ポイント）

| # | 変更内容 | 分類 |
|---|---|---|
| 1 | `dcs-env.md` → `dcs-env-definition.md`、`language.md` → `language-preferences.md` へ改名 | 命名の再定義 |
| 2 | `terraform-rules.md` を `coding-standards.md` へ統合して削除。統合後のファイルは `coding-conventions.md` へ改名 | 統合＋改名 |
| 3 | `spec-structure-rules.md` の手続き的な内容を各 Skill へ統合。命名関連の内容のみ残し `naming-conventions.md` へ改名 | 解体＋改名 |
| 4 | `workflow.md` を各 Skill へ統合したうえで廃止（削除）。パターン判定は LLM に任せず、**メンバーが Skill を明示指定して起動**する運用へ | 運用フローの合理化 |
| 5 | `agents/`・`hooks/` はフォルダのガワだけ配置（`.gitkeep` のみ。hooks は未検証のため導入見送り） | 土台の整備 |
| 6 | リポジトリルートに `AGENTS.md` を配置（生成 AI 向けの README・目次） | 土台の整備 |

### 期待効果

- **安定性**: 従来はすべての指示に対して LLM がパターン（A/B/C/D）を判定していたため、誤判定→steering への対症療法追加→運用の泥沼化、というリスクがあった。改訂後はメンバーが Skill を明示起動するため、**判定ミスが構造的に発生しない**。
- **コスト**: always 読み込みの steering が 3 本（language / workflow / spec-structure-rules）から 2 本（language-preferences / naming-conventions ※小型化済み）へ削減。毎ターンの注入量が減り、**クレジット消費と文脈希薄化の両方を抑制**。
- **保守性**: 「規約はどこに書くか」の置き場所が明確化（DRY / 単一情報源の徹底）。ファイル数が減り、重複記載の同期漏れリスクが低下。
- **移植性・互換性**: `AGENTS.md` は生成 AI エージェント向けドキュメントの業界的なベストプラクティス。他ツール・他チームへの展開時の入口として機能する。

---

## 2. 変更の背景（なぜ今この改訂か）

現行構成は機能してきたが、運用の中で以下の課題が顕在化した。

1. **パターン判定の不安定性**: `workflow.md`（always）が全指示に対して LLM 経由でパターン判定を行う設計だったが、パターン A〜D は実際には決まった手続きであり、あえて LLM の判断を挟む必然性がない。誤判定への対策として steering に指示を追加し続けても 100% の動作保証はできず、運用が複雑化する一方だった。
2. **クレジットの無駄**: 毎ターン `workflow.md` と `spec-structure-rules.md` を読み込ませたうえで判断させる構造は、判断が不要な場面でもコストがかかる。
3. **役割の境界のあいまいさ**: `spec-structure-rules.md` は「ルール」の名前ながら実態は手続き（生成手順・出力先）が混在し、Skill 側と重複記載があった。`terraform-rules.md` と `coding-standards.md` も観点が近接し、どちらに書くべきか迷いが生じていた。
4. **Tree 構造の二重管理**: フォルダ構成の Tree 図が README と steering に重複し、メンテナンスが煩雑。LLM への出力先指示も Tree より**パス直指定**の方が入力量・判断負担が少なく正確。

改訂の設計原則は次の 3 つ。

- **宣言的なルールだけを steering に残す**（手続きは Skill へ）
- **決まった手続きは LLM の判断を介さず、明示的なトリガーで起動する**
- **同じ情報は 1 箇所にだけ書く**（単一情報源＝「正」の徹底）

---

## 3. 全体アーキテクチャ（改訂後）

`.kiro/` は「役割の異なる層＋設定」で構成する。迷ったら「その情報はどの層の性質か」で置き場所を判断する。

| 層 | ディレクトリ | 役割（一言で） | 中身の性質 | 実行/読み込みの仕組み |
|---|---|---|---|---|
| steering | `.kiro/steering/` | 守るべきルール・環境事実 | 宣言的（規約・命名・環境前提・言語） | `inclusion`（always / fileMatch / manual）で読み込み制御 |
| skills | `.kiro/skills/` | タスクのやり方（手順書＋出力先） | 手続き的（設計書生成・コード生成・構成図生成） | **メンバーがコマンド＋引数（キーワード）で明示起動**。SKILL.md を入口に配下を段階展開 |
| agents | `.kiro/agents/` | （将来）カスタムエージェント定義 | — | **未導入。ガワのみ**（`.gitkeep`） |
| hooks | `.kiro/hooks/` | （将来）決定論的な機械作業の自動化 | — | **未検証のため導入見送り。ガワのみ**（`.gitkeep`） |
| settings | `.kiro/settings/` | ローカル設定（MCP 等） | 環境依存 | `mcp.example.json` のみ Git 管理。実動ファイルは gitignore |

**判断の指針:**

- 「常に守らせたいルール・環境の事実」→ steering
- 「特定タスクの実行手順・出力先・大きな参照資料」→ skills
- 「毎回きっちり同じことをやる整形・検証」→ 将来的には hooks 候補。**現時点では手動運用**（§7 参照）

> **旧構成との最大の違い**: 従来 steering にあった「ルーター」（workflow.md によるパターン判定）が存在しない。Skill の起動は人間の明示指示であり、steering は純粋に「ルール・事実」だけを持つ。

---

## 4. フォルダ構成（改訂後の完全ツリー）

```
cms-eng-spec-driven-development/
├── .kiro/                               # Kiro 設定（ルール・スキル）★Git 管理
│   ├── steering/                        # 横断ルール群（CSP 共通）
│   │   ├── coding-conventions.md        # コーディング規約（旧 coding-standards.md ＋ 旧 terraform-rules.md を統合）
│   │   ├── naming-conventions.md        # 命名規約（旧 spec-structure-rules.md の命名関連のみ残置）
│   │   ├── dcs-env-definition.md        # DCS Hub 環境定義（NW・CMS 標準動作）※旧 dcs-env.md
│   │   └── language-preferences.md      # 言語設定 ※旧 language.md
│   ├── agents/                          # 【ガワのみ】カスタムエージェント配置用（未導入）
│   │   └── .gitkeep
│   ├── hooks/                           # 【ガワのみ】Hooks 配置用（未検証・導入見送り）
│   │   └── .gitkeep
│   ├── settings/                        # ローカル設定（MCP 等）
│   │   └── mcp.example.json             # 例示用テンプレート ※実動ファイル（mcp.json）は .gitignore 対象
│   └── skills/                          # オンデマンド起動スキル群（明示起動・パターン判定なし）
│       ├── generate-design/             # 【パターンA】設計書生成 ※旧 design-doc
│       │   ├── SKILL.md                 # 入口：手順・出力先パス・必読 steering の指示
│       │   ├── parts/                   # CSP 別 記入ルール（案件 CSP 分のみ読込）
│       │   │   ├── aws.md
│       │   │   ├── azure.md
│       │   │   └── gcp.md
│       │   └── references/              # 設計書フォーマット定義
│       │       ├── aws-doc-format.md
│       │       └── azure-doc-format.md
│       ├── generate-code/               # 【パターンB】Terraform コード生成 ※旧 terraform-code
│       │   ├── SKILL.md
│       │   ├── parts/
│       │   │   ├── aws.md
│       │   │   ├── azure.md
│       │   │   └── gcp.md
│       │   └── references/              # モジュールカタログ
│       │       ├── aws-module-catalog.md
│       │       ├── azure-module-catalog.md
│       │       └── gcp-module-catalog.md
│       └── generate-diagram/            # 【パターンC】構成図（draw.io）生成 ※旧 drawio-diagram
│           └── SKILL.md
├── EngRepos/                            # 外部リポジトリ（Git Submodule 管理）★Git 管理
├── specs/                               # 🚫ローカル管理（.gitignore 対象）
├── Outputs/                             # 🚫ローカル管理（.gitignore 対象）
├── AGENTS.md                            # ★ 生成 AI 向け README（.kiro 全体像の目次・簡潔な箇条書き）
├── README.md
├── .kiroignore
├── .gitignore
└── .gitmodules
```

**主要な変更点（旧構成比）:**

- steering は 5 本 → **4 本**（規約 2 本＋環境定義＋言語）に集約。`workflow.md` は廃止。
- Skill 名は英語の**「動詞＋目的語」**で統一（`generate-design` / `generate-code` / `generate-diagram`）。一目で何をするスキルか判別可能。
- パターン D（設計書＋コード連続生成）は廃止。**A → B の順次実行**で代替（実運用上、連続生成は PoC フェーズ限定のため）。
- 出力先パスは各 SKILL.md 内で**パス直指定**。Tree 構造による定義は廃止（README との二重管理を解消）。
- `AGENTS.md` をルートに配置し、生成 AI がリポジトリ全体像を最初に把握できる目次として機能させる。

---

## 5. ファイルごとの位置付けと inclusion 設計

### 5-1. steering（4 本）

| ファイル | inclusion | 位置付け | この場所・このモードである理由 |
|---|---|---|---|
| `language-preferences.md` | always | 全応答を日本語に統一 | 普遍かつ極小。全対話で効かせたいので always が最適。 |
| `naming-conventions.md` | always | `project` 命名・Spec フォルダ命名など横断的な命名規約 | 命名は全生成パターンで必要、かつ「ファイルがまだ無い段階」で効かせる必要があるため fileMatch では拾えない。旧 spec-structure-rules から命名関連のみ残して小型化したため、always でもコスト負担が小さい。 |
| `coding-conventions.md` | fileMatch `**/*.tf` | Terraform コーディング規約の正（インデント・命名・count/for_each・コメント・ファイル命名・バージョン制約・backend 設定） | `.tf` を触る時だけ関係。人間の `.tf` 編集時にも自動で効き、無関係時は 0 コスト。旧 terraform-rules.md の内容（ディレクトリ構成・バージョン・backend）を統合し、Terraform に関する規約の正を 1 本化。 |
| `dcs-env-definition.md` | manual | DCS 環境の事実（NW/DC/接続）＋ CMS 標準動作（バックアップ・CloudTrail・SG/NSG・暗号化・命名・払い出し範囲） | 巨大かつ生成フェーズ以外では不要なため always にしない。**読み忘れ防止は各 SKILL.md 冒頭の「必読」指示で担保**（旧 workflow.md の役割を Skill へ移管）。 |

> **重要な設計変更**: 旧構成では `dcs-env.md`（manual）の読み忘れ防止を `workflow.md`（always）が担っていた。workflow.md 廃止に伴い、この担保は **generate-design / generate-code の各 SKILL.md 冒頭に「dcs-env-definition.md を必ず読み込む」と明記する**ことで引き継ぐ。Skill 統合作業時の必須要件。

### 5-2. skills（3 本・明示起動）

各 skill は「入口 `SKILL.md`（CSP 共通・手順・出力先）→ 案件 CSP の `parts/{cloud}.md` を 1 つだけ展開 → 必要な `references/*` を参照」という **progressive disclosure（段階的開示）** 構造を維持する。文脈肥大を防ぐため「他 CSP のファイルは読まない」ことを徹底する。

| skill | 旧名 | 生成物 | 出力先（SKILL.md 内にパス直指定） | SKILL.md が持つ内容 |
|---|---|---|---|---|
| `generate-design` | design-doc | 基本設計書 `design.md` | `Outputs/{cloud}/{project}/設計書/` | 手順・出力先・dcs-env-definition 必読指示・parts/references の読込指示（旧 workflow.md パターン A ＋旧 spec-structure-rules の該当手続きを統合） |
| `generate-code` | terraform-code | Terraform コード一式 | `Outputs/{cloud}/{project}/code/{env}/` | 同上（パターン B 相当）。モジュール利用の絶対原則（自前実装禁止）を維持。 |
| `generate-diagram` | drawio-diagram | `architecture.drawio` | `Outputs/{cloud}/{project}/設計書/` | 手順・出力先（パターン C 相当）。 |

**共通ルールの引き継ぎ**: 旧 workflow.md の「共通ルール」（全成果物・ログ・コメントは日本語／不明値は `[要確認]`／各フェーズは人間承認後に次へ／`{cloud}`・`project` はチャットから読み取る）は、各 SKILL.md へ統合する。

### 5-3. agents / hooks（ガワのみ）

- `agents/`・`hooks/` は `.gitkeep` のみ配置し、「定義は可能だが未導入」であることを構成上示す。
- hooks は**未検証のため導入を見送る**。従来 hook が担っていた `terraform fmt` / `terraform validate` は当面**手動運用**とする（§7）。検証完了後の導入時は本ガイドを更新する。

---

## 6. 作業フロー（明示起動・パターン判定なし）

### 6-1. 基本フロー

LLM によるパターン判定は行わない。**メンバーが実行したい Skill を明示的に指定して起動する**（コマンド＋引数のキーワードをトリガーとする）。

| やりたいこと | 起動する skill | 生成物 | 出力先 |
|---|---|---|---|
| 設計書を作る | `generate-design` | `design.md` | `Outputs/{cloud}/{project}/設計書/` |
| Terraform コードを作る | `generate-code` | Terraform 一式 | `Outputs/{cloud}/{project}/code/{env}/` |
| 構成図を作る | `generate-diagram` | `architecture.drawio` | `Outputs/{cloud}/{project}/設計書/` |
| 設計書とコードを続けて作る | `generate-design` → 人間承認 → `generate-code` | 上記を順に | 上記のとおり |

> 旧パターン D は廃止。設計書とコードを続けて作る場合も、**必ず設計書の人間レビュー・承認を挟んでから** generate-code を起動する（フェーズゲートは従来どおり維持）。

### 6-2. 各 skill 起動時に読み込まれるファイル

always の steering（`language-preferences.md` / `naming-conventions.md`）は常時読み込み済みのため記載しない。

- **generate-design**: `dcs-env-definition.md`（SKILL 冒頭指示により必読）＋ `SKILL.md` → `parts/{cloud}.md` → `references/{cloud}-doc-format.md`
- **generate-code**: `dcs-env-definition.md`（必読）＋ `SKILL.md` → `parts/{cloud}.md` → `references/{cloud}-module-catalog.md` ＋ 必要時 Terraform MCP。`.tf` 生成時は `coding-conventions.md` が fileMatch で自動適用。
- **generate-diagram**: `SKILL.md` のみ。

---

## 7. 手動運用事項（hooks 導入見送りに伴う暫定運用）

hooks が未検証のため、以下は**成果物を生成・修正した本人が手動で実行**する。

| 作業 | コマンド | タイミング |
|---|---|---|
| フォーマット | `terraform fmt -recursive`（対象は `Outputs/` 配下の該当 `code/`） | コード生成・修正後、レビュー依頼前 |
| 構文検証 | `terraform validate`（各環境ルート `stg/` `prd/` で実行。未 init なら `terraform init -backend=false` を先行） | 同上 |
| モジュール README | terraform-docs（必要な場合のみ） | modules 変更時 |
| 成果物 `code/` の `.gitignore` | テンプレートを手動配置 | 新規 code/ 作成時 |

> hooks の検証が完了し導入する際は、`.kiro/hooks/` に定義を追加のうえ、本節を「自動化済み」へ書き換える。

---

## 8. 単一情報源（正）マップ

「同じことを 2 箇所に書かない」を徹底する。各ルールの**唯一の定義場所（正）**は以下。修正時はまず正を直す。

| テーマ | 正（唯一の定義） | 参照する側（正を直せば追従） |
|---|---|---|
| `project` 命名・Spec フォルダ命名 | `naming-conventions.md` | 各 `SKILL.md` |
| 成果物の出力先パス | 各 `skills/*/SKILL.md`（パス直指定） | —（Tree 構造での二重定義は廃止） |
| Terraform ファイル命名（`versions.tf` / `providers.tf` 複数形・`backend.tf` 独立・`{env}.tfvars` 置き場） | `coding-conventions.md` | 各 `SKILL.md`、生成コード |
| Terraform / Provider バージョン制約 | `coding-conventions.md` | 生成される各 `versions.tf` |
| backend 設定方針（`.tfbackend` 外出し禁止） | `coding-conventions.md` | 生成される各 `backend.tf` |
| コーディング規約（インデント・count/for_each・コメント） | `coding-conventions.md` | —（旧 terraform-rules への要点再掲は統合により解消） |
| リソース命名フォーマット | `dcs-env-definition.md §11-6` | `parts/aws.md`・`parts/azure.md`・`naming-conventions.md` |
| CSP 別リソース略称表 | `generate-design` / `generate-code` の `parts/{cloud}.md` | 各 SKILL・設計書 |
| CMS 標準動作（バックアップ・CloudTrail・SG/NSG・暗号化・払い出し範囲） | `dcs-env-definition.md §11` | 両 skill の `parts/*` |
| 設計書 出力フォーマット | `generate-design/references/{cloud}-doc-format.md` | `generate-design/parts/{cloud}.md` |
| モジュールの inputs/outputs | EngRepos 各モジュールの `variables.tf` / `outputs.tf` | `generate-code/parts/*`、`references/*-module-catalog.md` |
| 作業手順・共通ルール（日本語成果物・`[要確認]`・人間承認） | 各 `skills/*/SKILL.md` | —（旧 workflow.md は廃止） |

---

## 9. 新旧対応表（移行マップ）

| 旧ファイル | 行き先 | 備考 |
|---|---|---|
| `steering/language.md` | `steering/language-preferences.md` | 改名のみ |
| `steering/dcs-env.md` | `steering/dcs-env-definition.md` | 改名のみ。「〇〇の△△」形式で役割の解像度を向上 |
| `steering/coding-standards.md` | `steering/coding-conventions.md` | terraform-rules.md を統合したうえで改名 |
| `steering/terraform-rules.md` | `coding-conventions.md` へ統合後、**削除** | ファイル命名・バージョン制約・backend 設定を移管 |
| `steering/spec-structure-rules.md` | 命名関連 → `naming-conventions.md`（残置・改名）／手続き（出力先・生成ルール） → 各 `SKILL.md` へ統合後、**削除** | 「ルール」と「手続き」の混在を解消 |
| `steering/workflow.md` | パターン判定・共通ルール・dcs-env 必読指示 → 各 `SKILL.md` へ統合後、**廃止（削除）** | LLM 判定から明示起動へ |
| `skills/design-doc/` | `skills/generate-design/` | 改名（動詞＋目的語）。中身は SKILL.md へ手続きを追記 |
| `skills/terraform-code/` | `skills/generate-code/` | 同上 |
| `skills/drawio-diagram/` | `skills/generate-diagram/` | 同上 |
| （パターン D） | **廃止** | A → B の順次実行で代替 |
| `hooks/` 配下の JSON / scripts / templates | **未導入化**（`.gitkeep` のみ残す） | 未検証のため。fmt/validate は手動運用（§7） |
| — | `AGENTS.md`（新規・ルート配置） | 生成 AI 向け目次 |
| — | `settings/mcp.example.json`（Git 管理） | 実動 `mcp.json` は gitignore |

---

## 10. 移行手順（合意後の実施ステップ）

依存関係を踏まえ、以下の順で実施する。各ステップ完了ごとに `.kiro/` 全体を grep して参照切れがないことを確認する。

1. **改名（影響小・先行実施）**: `dcs-env.md` → `dcs-env-definition.md`、`language.md` → `language-preferences.md`。全参照を grep 置換。
2. **統合①**: `terraform-rules.md` の内容を `coding-standards.md` へ統合 → `terraform-rules.md` を削除 → `coding-standards.md` を `coding-conventions.md` へ改名。fileMatch 設定（`**/*.tf`）を維持。
3. **統合②（Skill 側の受け皿づくり）**: 各 Skill を `generate-design` / `generate-code` / `generate-diagram` へ改名。各 SKILL.md へ、旧 workflow.md の該当パターン手順・共通ルール・出力先パス（直指定）・`dcs-env-definition.md` 必読指示を統合。
4. **解体**: `spec-structure-rules.md` から手続き部分を各 SKILL.md へ移し、命名関連のみ残して `naming-conventions.md` へ改名（inclusion: always を維持）。
5. **廃止**: `workflow.md` を削除。`agents/`・`hooks/` を `.gitkeep` のみのガワにする（hooks の既存定義はブランチ or アーカイブへ退避し、検証再開時に利用）。
6. **土台**: ルートに `AGENTS.md` を配置（.kiro 全体像の簡潔な目次）。`settings/mcp.example.json` を整備し、`.gitignore` に実動設定の除外を定義。
7. **動作確認**: 3 つの skill をそれぞれ明示起動して 1 回ずつ生成を回し、(a) 出力先パスが正しい、(b) dcs-env-definition が読み込まれ CMS 標準動作が反映されている、(c) `.tf` 生成時に coding-conventions が効いている、の 3 点を確認。
8. **本ガイドの確定**: 実態と本ガイドの差分がないことを確認し、旧ガイドを置き換える。

---

## 11. メンテナンスガイド（シナリオ別）

> 原則: 正（§8）を直す。参照側は原則触らない。ファイル名を変えたら `.kiro/` 全体を grep。`.kiro/` を変えたら本ガイドも更新。

| いつ（トリガー） | 編集ファイル・箇所 | 直後の注意 |
|---|---|---|
| リソース命名規則そのものを変える | `dcs-env-definition.md §11-6`（正） | リソース略称表（各 skill の `parts/*`）は別管理なので必要なら併せて更新。既存生成物の命名は自動では変わらない。 |
| CSP 別の略称・記入ルールを追加/変更 | 該当 `skills/*/parts/{cloud}.md` | `SKILL.md` には書かない（重複禁止）。見出し ID（`AWS-x` / `Azure-x` / `GCP-x`）規約を維持。 |
| CMS 標準動作を変える | `dcs-env-definition.md §11` | manual のため、generate-design / generate-code の SKILL.md に必読指示が残っているか確認。 |
| Terraform コーディング規約・ファイル命名・バージョン・backend を変える | `coding-conventions.md`（正が 1 本化されたのでここだけ） | fileMatch なので `.tf` 作業時に自動反映。 |
| `project` 命名・Spec フォルダ命名を変える | `naming-conventions.md`（正） | always なので即全体反映。 |
| 成果物の出力先を変える | 該当 `skills/*/SKILL.md` のパス直指定箇所 | Tree 図の更新は不要（廃止済み）。README の記載と齟齬がないか目視確認。 |
| Skill の手順・参照サブファイルを増減する | 該当 `SKILL.md` の参照表 | 他ファイルは触らない（workflow.md は存在しない）。 |
| 新しい skill を追加する | `skills/<動詞-目的語>/SKILL.md` を新規作成 | 命名は英語「動詞＋目的語」で統一。出力先パス直指定・必読 steering の指示・共通ルールを SKILL.md 内に完結させる。 |
| manual の steering を増やす | 新 steering 追加 ＋ **それを必要とする各 SKILL.md に「必ず読み込む」を追記** | 旧 workflow.md 方式と異なり、担保先は Skill 側。追記漏れ＝読み忘れリスク。 |
| hooks を導入する（検証完了後） | `hooks/` に JSON・scripts を配置 | §7 の手動運用事項を「自動化済み」へ書き換え。0 クレジット（command 型）・非ブロッキング・Outputs/ 限定スコープの原則を推奨。 |
| MCP サーバを追加/変更 | `settings/mcp.json`（ローカル）＋ 共有すべき例は `mcp.example.json` | 実動ファイルは Git 管理外。チームで共有したい接続例は example 側へ反映。 |

---

## 12. よくある落とし穴・トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| 出力先が想定と違う場所に生成される | 起動した skill の SKILL.md 内パス指定の誤り／`{cloud}`・`project` の指定漏れ | チャットで `{cloud}` / `project` を明示。SKILL.md のパス直指定を確認。 |
| CMS 標準動作（SG 新規作成しない等）が反映されない | `dcs-env-definition.md`（manual）が読み込まれていない | SKILL.md 冒頭の必読指示が残っているか確認。手動で `#dcs-env-definition.md` を渡す。 |
| 意図しない skill が動く／動かない | skill を明示指定していない（旧運用の癖で自然言語だけで指示） | **skill 名を明示して起動する**のが新運用の前提。`description` 頼みの dispatch には依存しない。 |
| fmt/validate がかかっていない成果物がレビューに出る | hooks 廃止（未導入）に伴う手動実行の漏れ | §7 の手動運用チェックをレビュー依頼前の必須手順としてチームで徹底。 |
| 参照リンク切れ | ファイル改名時の参照更新漏れ | 改名時は必ず `.kiro/` 全体＋ README ＋ AGENTS.md を grep して更新。 |
| 規約がどこに書いてあるか分からない | — | §8 の正マップを参照。Terraform 関連の規約はすべて `coding-conventions.md`、横断命名は `naming-conventions.md`。 |

---

## 13. 設計上の前提・既知の未整備事項

**前提・思想（継続）:**

- `Outputs/` と `specs/` は Git 管理対象外。ワークスペースは「生成の作業場」であり、成果物 `code/` は納品時に独立管理する想定。
- 責任分界: DCS（Global）＝アカウント/ネットワーク払い出し、JP CMS（CI）＝VM 構築・標準エージェント導入、JP CMS（Eng）＝設計・構築（本仕様駆動開発）。Hub 環境では払い出し済みリソースは新規作成せず既存参照。
- モジュール利用の絶対原則: Terraform リソースは原則自前で書かず EngRepos モジュールをコピー＆カスタマイズ。

**既知の未整備（対応時は本ガイドと SKILL の注記も更新）:**

- `agents/`・`hooks/` は未導入（ガワのみ）。hooks は検証完了後に導入判断。
- `generate-design/references/gcp-doc-format.md` 未整備。GCP 系 `parts/*` は未検証。
- Azure のリソース略称表が未整備。
- Azure / GCP の Provider バージョン詳細は検証完了後に `coding-conventions.md` へ追記。
- SG/NSG 標準ルールは「方針調整中」。

---

## 14. 変更時の共通チェックリスト

1. 直そうとしている情報の**「正」はどこか**（§8）を確認し、正だけを直す。
2. 参照側（SKILL / parts）に重複定義していないか（重複していたら正へ集約）。
3. ファイル名を変えたら `.kiro/`・README・AGENTS.md を grep して参照を更新。
4. manual の steering を足したら、**必要とする各 SKILL.md** に読み込み指示を追記（担保先は workflow.md ではなく Skill）。
5. always を足す前に分量を確認（大きいなら core / detail に分割し、detail は manual＋SKILL 必読指示）。
6. 変更後、関係する skill を明示起動して実際に生成を一度回し、齟齬がないか確認。
7. コード成果物は fmt / validate を手動実行してからレビュー依頼（§7）。
8. 本運用ガイドの該当箇所を更新。

---

## 15. 用語集

| 用語 | 意味 |
|---|---|
| steering | Kiro に常時/条件付きで読み込ませる「ルール・環境事実」。`inclusion` で制御。 |
| skill | タスク手順書。`SKILL.md` を入口に段階的に配下を読み込む。本改訂以降は**明示起動**が前提。 |
| 明示起動 | メンバーがコマンド＋引数（キーワード）で skill を直接指定して実行すること。LLM のパターン判定を介さない。 |
| inclusion | steering の読み込みモード（always / fileMatch / manual）。 |
| 正（single source of truth） | ある情報の唯一の定義場所。他は参照するだけ。 |
| progressive disclosure | 入口 SKILL.md → 案件 CSP の parts → references の順に必要な分だけ段階的に読み込む構造。 |
| AGENTS.md | 生成 AI エージェント向けの README（目次）。ベストプラクティスに準拠したルート配置ファイル。 |
| DCS Hub / Disconnected | 社内 NW 接続クラウド / 非接続クラウド。CMS 標準動作が変わる。 |
| CSP | Cloud Service Provider（aws / azure / gcp）。 |