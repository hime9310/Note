# Spec フォルダ・ファイル命名規則

チーム全体でSpecフォルダ・ファイルの構成を統一するためのルールです。

---

## 1. フォルダ構成

```
specs/{cloud}/{project}/
```

| プレースホルダー | 説明 | 値 |
|---|---|---|
| `{cloud}` | クラウド種別 | `aws` / `azure` / `gcp` |
| `{project}` | 案件名（inputs配下と同名） | 例：`cms-kiro-test` |

### 例

```
specs/
└── aws/
    └── cms-kiro-test/       # inputs/aws/cms-kiro-test/ と同名
        ├── requirements.md
        ├── design.md
        └── tasks.md
```

---

## 2. project の命名ルール

- すべて **小文字・ハイフン区切り**（スネークケース・大文字禁止）
- `{サービス名}-{用途}` の形式を基本とする
- **inputs配下の案件フォルダ名と必ず一致させること**

| 良い例 | 悪い例 |
|---|---|
| `cms-kiro-test` | `CMS_Kiro_Test` |
| `ec2-rds-hub` | `EC2RDSHub` |
| `aks-cluster` | `aks_cluster` |

---

## 3. 必須ファイルと生成フェーズ

| ファイル | Phase | 内容 | 生成者 |
|---|---|---|---|
| `requirements.md` | Phase 1 | ユーザーストーリー・機能要件・非機能要件・受け入れ基準 | Kiro生成 → 人間が承認 |
| `design.md` | Phase 2 | アーキテクチャ・コンポーネント設計・ネットワーク・セキュリティ | Kiro生成 → 人間が承認 |
| `tasks.md` | Phase 3 | チェックボックス付き実装タスクリスト | Kiro生成 → 人間が承認 |

---

## 4. ファイル生成ルール

- Kiroは人間の承認なしに次のPhaseへ進まないこと
- 各ファイルは人間がレビュー・承認してから次へ進む
- 不明項目は空白にせず必ず `[要確認]` とマークすること
- specsフォルダはKiroが自動作成するため、事前の手動作成は不要

---

## 5. inputs と specs の対応関係

案件フォルダ名は inputs・specs・src すべて同名で統一する。

```
inputs/aws/cms-kiro-test/   ← インプット情報（QA票・パラメーターシート・構成図）
specs/aws/cms-kiro-test/    ← Kiroが生成するSpec（requirements / design / tasks）
src/aws/cms-kiro-test/      ← Kiroが生成するTerraformコード一式
```

---

## 6. 検証フェーズのスコープ

| クラウド | 検証フェーズ | 備考 |
|---|---|---|
| AWS | ✅ 対象 | 検証中 |
| Azure | ⏳ 保留 | 検証完了後に開始 |
| GCP | ⏳ 保留 | 検証完了後に開始 |
