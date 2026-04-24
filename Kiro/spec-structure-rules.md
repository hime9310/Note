# Spec フォルダ・ファイル命名規則

## フォルダ構成
specs/{cloud}/{project}/
　例：specs/aws/ec2-rds-hub/
　　　specs/azure/aks-cluster/
　　　specs/gcp/gke-node/

## cloud の値
| 対象 | フォルダ名 |
|------|-----------|
| AWS  | aws       |
| Azure| azure     |
| GCP  | gcp       |

## project の命名ルール
- すべて小文字・ハイフン区切り（スネークケース禁止）
- サービス名-用途 の形式を基本とする
- 例：ec2-rds-hub / aks-cluster / gke-node-pool

## 必須ファイル（Kiroが自動生成・人間が承認）
| ファイル | Phase | 内容 |
|----------|-------|------|
| requirements.md | Phase1 | ユーザーストーリー・機能要件・受け入れ基準 |
| design.md       | Phase2 | アーキテクチャ・コンポーネント設計 |
| tasks.md        | Phase3 | チェックボックス付き実装タスクリスト |

## ファイル生成ルール
- Kiroが勝手に次のPhaseへ進まないこと
- 各ファイルは人間がレビュー・承認してから次へ進む
- 不明項目は空白にせず必ず [要確認] とマークすること