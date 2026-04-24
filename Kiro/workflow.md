# Kiro 作業フロー定義（CSP共通）

## 共通ルール
- クラウド種別（aws / azure / gcp）と案件名は
  チャットの指示から読み取ること
- インプット情報は inputs/{cloud}/{project}/ を参照すること
- Specの出力先・命名は spec-structure-rules.md に従うこと

## コード生成時の必須制約（常時適用）
以下は coding-standards.md・terraform-rules.md から自動適用する：

### フォーマット
- インデントは半角スペース2個
- コミット前に terraform fmt を必ず実行
- variables.tf の各変数には description と type を必ず記載

### 命名規則
- リソースブロック名は特別な理由がない限り this を使用
- ブランチ名：feature-{バックログ課題キー} 形式

### ファイル構成（出力必須ファイル）
src/{cloud}/{project}/ 配下に以下を生成すること：
- main.tf      モジュール呼び出し・リソース定義
- variables.tf  入力変数（description・type 必須）
- outputs.tf    出力値定義
- version.tf    Terraform・Providerバージョン制約
- provider.tf   Providerの設定

### バージョン制約（terraform-rules.md 準拠）
- Terraform本体：~> 1.14.0
- AWS Provider：hashicorp/aws ~> 6.14.1
- Azure Provider：hashicorp/azurerm ~> 3.0
- GCP Provider：hashicorp/google ~> 6.0
- ~> を使うこと（>= は使わない）

### コード記述ルール
- count / for_each はリソースブロック内1行目に記載・末尾に空行1行
- 空値は null を使用（空文字 "" は禁止）
- デプロイスクリプト・CI/CDは生成しない
- 変数のハードコード禁止（すべて variables.tf に集約）

### コミットメッセージ
- feat / fix / modify / docs / refactor のプレフィックスをつける

---

## ① requirements.md の作成を依頼された場合
参照：
1. inputs/{cloud}/{project}/qa-table.md（または .xlsx）
2. inputs/{cloud}/{project}/parameter-sheet.md（または .xlsx）

出力：specs/{cloud}/{project}/requirements.md
形式：ユーザーストーリー / 機能要件 / 非機能要件 / 受け入れ基準（チェックボックス）

## ② 基本設計書の作成を依頼された場合
参照：
1. inputs/{cloud}/{project}/qa-table.md（または .xlsx）
2. inputs/{cloud}/{project}/parameter-sheet.md（または .xlsx）
3. specs/{cloud}/{project}/requirements.md（存在する場合）
4. .kiro/skills/design-doc/references/design-template.md
5. .kiro/skills/design-doc/references/images-template.png

出力：specs/{cloud}/{project}/design.md
ルール：
- フォーマットは design-template.md を厳守
- 不明項目は [要確認] とマーク（空白禁止）

## ③ Terraformコードの作成を依頼された場合
参照：
1. specs/{cloud}/{project}/design.md
2. specs/{cloud}/{project}/requirements.md
3. Eng-repos/{Cloud}Repos/ 配下の既存モジュール（優先使用）
4. .kiro/skills/terraform-patterns/references/module-catalog.md

出力：src/{cloud}/{project}/
　　　main.tf / variables.tf / outputs.tf / version.tf / provider.tf
ルール：
- 既存モジュール優先・新規作成は最小限
- デプロイスクリプト・CI/CDは生成しない