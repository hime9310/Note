# Kiro CLI ガイド（Windows）— 紹介・導入・トラブルシューティング

本書は Kiro CLI の概要と、Windows 環境でのインストール・初期設定・トラブルシューティング手順をまとめたものです。本チームでは **通常の生成作業は IDE 版 Kiro（`/generate-*`）を正**とし、CLI は **IDE でエラーが発生した際の切り分け・応急対応ツール**として位置づけます。

---

## 1. Kiro CLI とは（Claude Code と同じ？）

- **ターミナル上で動く AI エージェント**です。位置づけは Claude Code と同じカテゴリで、ターミナルで対話しながらコードの生成・説明、シェルコマンドの実行、ファイル編集ができます。バイナリ名は `kiro-cli` です。
- 旧 **Amazon Q Developer CLI** が、2025 年 11 月の Kiro GA にあわせて **Kiro CLI に統合・改名**されたものです。
- **IDE 版 Kiro との関係**: 同じ Kiro アカウント・**クレジットを共有**します。IDE ＝ Spec・steering・skills を使った GUI での開発、CLI ＝ ターミナルでの軽量対話・自動化、という住み分けです。
- 一般的な用途: ターミナルでのちょっとした質問・調査、シェルコマンドの生成（`kiro-cli translate`）、CI/CD への組み込み（**headless モード**: `kiro-cli chat --no-interactive "プロンプト"`。CLI 2.0 で追加）、カスタムエージェント運用など。
- **本チームでの用途**: IDE 障害時の①環境診断（`doctor`）、②原因切り分け（認証・接続が生きているか）、③復旧までの作業継続（チャットでのエラー調査・コマンド実行）。CLI から `/generate-*` スキルを起動する運用は行いません（スキル体系は IDE 前提のため）。

## 2. インストール（Windows・初回のみ）

**前提**: Windows 10/11（64bit）。**Kiro CLI 2.0 以降は Windows ネイティブ対応**です（WSL は不要。「WSL が必要」と書かれた記事は 2.0 より前の旧情報です）。IDE 版 Kiro 導入済みの端末に共存インストールして問題ありません。

1. 公式ドキュメント **https://kiro.dev/docs/cli/installation/** から Windows 用インストーラを取得し、実行する
2. **新しい PowerShell ウィンドウを開く**（※インストール直後の既存ウィンドウは PATH が未反映のため、`kiro-cli` が見つかりません。ここが最初のつまずきポイントです）
3. バージョン確認:

```powershell
kiro-cli --version
```

**✔ 確認**: バージョン番号（2.x 以上）が表示される。

## 3. 初期設定

1. ログイン:

```powershell
kiro-cli login
```

2. ブラウザが起動し、サインイン方法の選択肢（Google / GitHub / Builder ID / **Your Organization**）が表示されます。**チーム標準は「Your Organization」→ AWS IAM Identity Center** です（IDE と同じ。個人の Google / Builder ID は使用しない）。
3. ログイン確認:

```powershell
kiro-cli whoami
```

4. 動作確認 — チャットを起動して 1 問投げ、応答が返れば OK:

```powershell
kiro-cli chat
# 例: 「このディレクトリのファイル一覧を出して」
# 終了は /quit（または Ctrl+D）
```

**✔ 確認**: `whoami` に組織アカウントが表示され、`chat` で応答が返る。

## 4. 基本操作チートシート（トラブル対応で使う最小セット）

| コマンド | 用途 |
|---|---|
| `kiro-cli chat` | 対話チャットを開始（作業ディレクトリごとに会話が保持される） |
| `kiro-cli chat --resume` | 前回セッションを再開 |
| `!<コマンド>` | チャット内で AI を介さずシェルコマンドを直接実行（例: `!terraform validate`） |
| `/context` | セッションに読み込まれているファイル・コンテキストを確認 |
| `/usage` | クレジット等の使用状況を表示 |
| `/quit` | チャット終了 |
| `kiro-cli translate "やりたいこと"` | 自然言語からシェルコマンドを生成 |
| `kiro-cli update` | CLI を最新版へ更新 |
| `kiro-cli login` / `logout` / `whoami` | 認証まわり |

## 5. トラブルシューティングでの使い方（本チームの想定用途）

### 5-1. まずはこれ: `kiro-cli doctor`

```powershell
kiro-cli doctor           # 一般的な問題を診断し、可能なものは自動修正
kiro-cli doctor --all     # 全項目を診断（修正はしない）
kiro-cli diagnostic       # 詳細な診断情報を出力（問い合わせ時の添付用）
```

`✔ Everything looks good!` が出れば、認証・接続など Kiro の共通基盤は正常です。

### 5-2. IDE で問題が起きたときの切り分けフロー

1. **`kiro-cli doctor` を実行する。**
   - **NG が出る場合** → 認証・ネットワークなど IDE と共通の基盤側の問題である可能性が高い。`kiro-cli login` で再認証、社内プロキシ／ネットワーク設定を確認、`kiro-cli update` で最新化。復旧後に IDE 側も再起動して確認。
   - **OK なのに IDE だけ不調な場合** → IDE 固有の問題。IDE の再起動 → ワークスペースの信頼確認 → それでも直らなければ IDE の再インストール（バージョン運用は 04 運用手順書参照）。
2. **復旧までの作業継続**: `kiro-cli chat` を代替手段として使用。IDE のエラーメッセージを貼って原因を調査させる、`!terraform fmt -recursive` や `!terraform validate` などの検証コマンドを実行する、といった応急対応が可能です。
3. **生成が異常に遅い／止まる場合**: `/usage` でクレジット状況を確認、`kiro-cli whoami` でログイン状態を確認。夕方はアクセス集中で遅くなる傾向がある点も考慮（03 利用手順書 §1 Tips）。
4. **解決しない場合**: デバッグログを有効にして再現し、ログを添えてチーム窓口へ。公式への報告は `kiro-cli issue` から可能です。

```powershell
$env:KIRO_LOG_LEVEL = "debug"   # このウィンドウ内のみ有効
kiro-cli chat                    # 事象を再現
```

### 5-3. 症状別クイック対処表

| 症状 | 対処 |
|---|---|
| IDE が起動しない・チャットに応答がない | `kiro-cli doctor` → NG なら認証・NW を復旧（§5-2 手順 1）。OK なら IDE 再起動 → 再インストール |
| ログインエラー（IDE） | `kiro-cli login`（Your Organization）で CLI 側から認証確認。CLI で通るなら IDE 側の認証キャッシュを疑い、IDE でサインアウト → 再サインイン |
| `kiro-cli` コマンドが見つからない | **新しいターミナルを開く**（PATH 未反映）。それでも不可ならインストーラを再実行 |
| CLI の応答がおかしい・古い | `kiro-cli update` → `kiro-cli doctor` |
| IDE の MCP（terraform / drawio）が繋がらない | CLI ではなく **02 導入手順書 Step 3〜5** で切り分け（mcp.json のパス・バイナリ単体起動）。CLI の MCP 設定は IDE と体系が異なるため、この切り分けには使用しない |
| クレジット枯渇が疑われる | `kiro-cli chat` → `/usage` で確認（IDE と共有のため CLI から確認可能） |

### 注意事項

- **クレジットは IDE と共有**です。CLI での生成・チャットも消費します（doctor 等の診断コマンドは対象外）。
- CLI にも steering / agents / hooks / MCP の仕組みがありますが、**設定体系は IDE と別**です。本チームの生成ルール（`.kiro/` 配下）の正は IDE 運用であり、**CLI から `.kiro/` 配下を編集しない**でください（トラブル調査での読み取り・相談までに留める）。
- チャット中のコマンド実行は都度承認が基本です。`--trust-all-tools`（全ツール自動承認）は使用しないでください。

## 6. 更新・その他

```powershell
kiro-cli update                    # 最新版へ更新
kiro-cli version --changelog      # 現バージョンの変更点を表示
kiro-cli --help-all               # 全コマンド一覧
```

参考: 公式ドキュメント https://kiro.dev/docs/cli/ ／ インストール https://kiro.dev/docs/cli/installation/
