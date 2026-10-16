# arch-review-copilot

GitHub Copilot(VS Code)でアーキテクチャレビュー(Mermaid化 → 構成図情報抽出 → ホスティング判定 → 構成図チェック → レビュー票作成 → 回答回収 → 2次チェック → ナレッジ文案)を行うためのリポジトリ。
Copilot Studio 版で課題だった「ツール直後の応答の不安定さ」「30分で会話が切れる」「複数案件を並行できない」を、次の3つの方針で解消する。

- 案件の状態は会話ではなくファイル(`cases/<RITM>/`)に持つ。翌日の再開・複数案件の並行・やり直しはフォルダを開き直すだけ
- 決定的な処理(観点の絞り込み・下書き・検算・Excel書き込み)は `scripts/` の Python に任せ、LLM は判定と文章だけを行う
- M365(Teams / SharePoint)との出入りは読み取り専用の MCP サーバー(`mcp_graph_ro/`)に限定し、投稿や書き込みは人または Webhook で行う

---

## フォルダ構成と役割

```
arch-review-copilot/
├ .github/
│  ├ copilot-instructions.md        共通ルール(全エージェントに常に適用)
│  ├ agents/                        工程ごとのカスタムエージェント(.agent.md)
│  ├ prompts/                       Eng が呼ぶ入口(/judge /check …)(.prompt.md)
│  └ skills/                        スクリプトの使い方(SKILL.md)
├ .vscode/
│  └ mcp.json                       MCP サーバーの登録
├ mcp_graph_ro/                     読み取り専用 Microsoft Graph MCP サーバー
├ scripts/                          決定的な処理(Python)
├ reference/                        参照データ(KO要件・観点表・テンプレート・Salus)
├ cases/                            案件ごとの入出力(Git 管理外)
├ .gitignore
└ README.md                         このファイル
```

### `.github/copilot-instructions.md` — 共通ルール
全エージェント・全チャットに自動で適用される指示。Copilot Studio 版の「共通厳守事項」をそのまま移植する場所。
- 入れるもの: 出力はすべて案 / 推測で補わない / 検算の分母はスクリプトの件数 / Markdown の書式(状態行・見出し・箇条書き・全角「｜」)/ 成果物の保存先と命名 / graph-ro は読み取り専用
- 入れないもの: 工程固有の手順(それは agents/ に書く)

### `.github/agents/` — カスタムエージェント(工程ごと)
1工程=1ファイル。Copilot Studio 版の子Agentの指示文に相当し、「役割・手順・出力形式・使ってよいツール」を書く。フロントマターの `tools` で、そのエージェントが呼べるツール(MCP のツール名、`edit`、`runCommands` など)を絞る。

| ファイル | 役割 | 読む材料 | 書く成果物 |
|---|---|---|---|
| `diagram.agent.md` | 構成図(画像)を Mermaid に書き起こす | `cases/<RITM>/input/構成図.png` | `output/01_mermaid.md` |
| `extract.agent.md` | Mermaid からサービス一覧・NW情報を抽出 | `01_mermaid.md` | `output/02_inventory.md` |
| `hosting.agent.md` | DCS Hub / Disconnected を判定、Salus 照合 | `02_inventory.md`、Teamsスレッド(MCP)、`reference/ko_requirements.md`、`reference/salus.md` | `output/03_hosting.md` |
| `check.agent.md` | 観点ごとに記載の有無を判定し、下書きの [ ] を埋める | `04_points.md`、`04_draft.md`(scripts が生成)、`01〜03`、`input/thread.md` | `output/04_check.md` |
| `sheet.agent.md` | レビュー票の編集指示(①流用②添削③追記④不要)と票 JSON | `03_hosting.md`、`04_check.md`、`reference/template_<CSP>.md` | `output/05_ticket.json` |

- 書式(`description` / `tools` など)は VS Code の更新で変わることがあるため、着手時に公式ドキュメントで確認する
- 指示文の本文は現行 Copilot Studio 版からの移植。ツール呼び出しの部分だけ「ツール【/…】」→「graph-ro/get_thread」や「ターミナルで python scripts/… を実行」に書き換える

### `.github/prompts/` — Eng が呼ぶ入口
チャットで `/judge` のように呼ぶプロンプトファイル。どのエージェントを使うか(`agent:`)と、RITM などの入力(`${input:ritm}`)を受け取り、エージェントに渡す。Copilot Studio 版の「親Agentの対応表(指示語 → 子)」に相当するが、「次の操作」の案内は不要(手順は本 README の「使い方」)。

| ファイル | 呼び方 | 使うエージェント |
|---|---|---|
| `mermaid.prompt.md` | `/mermaid` + 画像添付 | diagram |
| `extract.prompt.md` | `/extract` | extract |
| `judge.prompt.md` | `/judge` | hosting |
| `check.prompt.md` | `/check`(1次)/ `/check2`(2次) | check |
| `ticket.prompt.md` | `/ticket` | sheet |
| `answers.prompt.md` | `/answers`(回答済み票の取り込み) | sheet |

### `.github/skills/` — スクリプトの使い方
`<スキル名>/SKILL.md` にスクリプトを「いつ・どう実行し・何が出力されるか」を書く。エージェントがスクリプトを正しいタイミング・引数で呼ぶための説明書。

| フォルダ | 対象スクリプト | 内容 |
|---|---|---|
| `checkpoint-filter/` | `scripts/filter_checkpoints.py` | /check の最初に必ず実行。環境・CSP・1次/2次で観点を絞り、`04_points.md` と `04_draft.md` を作る |
| `ticket-excel/` | `scripts/write_ticket.py` | `05_ticket.json` をテンプレート xlsx に書き込む。キー8つの決まり |
| `graph-tool/` | `mcp_graph_ro/` | find_thread → get_thread の順で使う、チャネルキーは config.json のもの、取得したスレッドは `input/thread.md` に保存する、など |

### `.vscode/mcp.json` — MCP サーバーの登録
`mcp_graph_ro/server.py` を `graph-ro` という名前の stdio サーバーとして登録する。ワークスペースを開くと VS Code が起動し、エージェントから `graph-ro/<ツール名>` で呼べるようになる。設定ファイルの場所は環境変数 `ARCHREVIEW_CONFIG` で渡す。

### `mcp_graph_ro/` — 読み取り専用 Graph MCP サーバー
Teams スレッドと SharePoint ファイルを Microsoft Graph から取得するだけのサーバー。書き込み系の API(POST/PATCH/DELETE)はコードに含めない。

| ファイル | 内容 |
|---|---|
| `server.py` | MSAL(委任、認可コード+PKCE、暗号化トークンキャッシュ)と5ツール: `find_thread` / `get_thread` / `list_folder` / `get_file` /(将来)`find_channel` |
| `config.json` | テナントID・クライアントID(Global App Reg Tool で登録したもの)、認証フロー、許可するチーム/チャネル/サイトのID、ダウンロード先 |
| `requirements.txt` | mcp / msal / msal-extensions / requests |

- 必要な委任権限: `ChannelMessage.Read.All`、`Sites.Read.All`(または `Files.Read.All`)、`User.Read`、`offline_access`。Teams・SharePoint の2つは社内の既定9権限の外なので Global CyberSecurity への承認申請+SSDLC が必要
- 初回起動時にブラウザでサインイン。以後はトークンキャッシュ(`~/.archreview/token_cache.bin`、暗号化)を使う
- `config.json` の ID は環境ごとに違うため、Git には `config.sample.json` を入れ、実物はコミットしない運用を推奨

### `scripts/` — 決定的な処理(Python)
LLM に任せると不安定になる処理を、入力と出力が決まった処理として実装する。Copilot Studio 版のエージェントフロー(T2・T4・T5)の式に相当する。

| ファイル | 相当する旧ツール | 入力 | 出力 |
|---|---|---|---|
| `filter_checkpoints.py` | T2 構成図チェック観点取得 | `reference/checkpoints.md`、RITM、環境、CSP、1次/2次 | `cases/<RITM>/output/04_points.md`(判定材料)、`04_draft.md`(下書き)、適用行数 |
| `verify.py` | 各Agentの「検算」 | `04_check.md`、`04_points.md` | 区分合計と適用行数の一致、未記入 [ ] の有無(終了コードで判定) |
| `write_ticket.py` | T4 アーキテクチャレビュー票Excel作成 | `05_ticket.json`、`reference/【案件名】(RITMxxxxxxx)アーキテクチャレビュー票(<CSP>).xlsx` | `cases/<RITM>/output/【案件名】(<RITM>)アーキテクチャレビュー票(<CSP>).xlsx` |
| `read_answers.py`(Phase 4) | T5 回答済みアーキテクチャレビュー票取得 | 回答済み xlsx(MCP または OneDrive 同期で取得) | `cases/<RITM>/output/06_answers.md`(回答済み/未回答/要確認の仕分け材料) |
| `post_teams.py`(Phase 4) | — | 投稿文、Teams Workflows Webhook の URL | チャネルへの投稿(書き込みはここだけ。Graph は使わない) |

### `reference/` — 参照データ
判定・チェック・票作成の「正」になるデータ。SharePoint の `Agent連携用/` を正として、OneDrive 同期またはコピーで置く。内容は変更しない(変更は SharePoint 側で行い、同期する)。

| ファイル | 用途 | 使うエージェント/スクリプト |
|---|---|---|
| `ko_requirements.md` | ノックアウト要件一覧(ID / No. / 要因 / 具体的なケース / 判断区分 / 備考) | hosting |
| `salus.md` | Salus Status 一覧 | hosting |
| `checkpoints.md` | 構成図チェック観点表(No / 大分類 / チェック観点 / 判断基準 / 対象CSP / 環境 / テンプレート対象No / AI判定可否 / チェックタイミング / 判定トリガー / ネクストアクション / AI判定方法 / AI出力内容 / 備考) | filter_checkpoints.py |
| `【案件名】(RITMxxxxxxx)アーキテクチャレビュー票(AWS|Azure|GCP).md` | 票テンプレート(行の正) | sheet |
| `【案件名】(RITMxxxxxxx)アーキテクチャレビュー票(CSP名).xlsx` | Excel の雛形 | write_ticket.py |
| `service_resources.md` | サービス提供対象リソース一覧(申し送り用。Phase 4) | sheet |

- 機密区分の都合でリポジトリに置けない場合は、`reference/` を `.gitignore` に追加し、各 Eng が同期フォルダから配置する

### `cases/` — 案件ごとの入出力(Git 管理外)
案件(RITM)ごとに1フォルダ。これが「会話の代わりの状態」で、翌日の再開も複数案件の並行もこのフォルダ単位で行う。`.gitignore` 済みで、案件データはリポジトリにコミットしない。

```
cases/RITM1234567/
├ input/
│  ├ 構成図.png          利用者から受領した構成図(手動配置)
│  └ thread.md           Teams スレッド本文(MCP get_thread が保存。手動コピーでも可)
└ output/
   ├ 01_mermaid.md       確定図(Mermaid + 注釈情報)
   ├ 02_inventory.md     【構成図一覧】
   ├ 03_hosting.md       【ホスティング判定結果】
   ├ 04_points.md        判定材料(scripts が生成。1観点1行)
   ├ 04_draft.md         【構成図チェック結果】の下書き(scripts が生成。[ ] 付き)
   ├ 04_check.md         【構成図チェック結果】(check エージェントが [ ] を埋めたもの)
   ├ 05_ticket.json      票の行(No. / ステータス / 環境 / 対応区分 / カテゴリ / 指摘概要 / 指摘内容 / 対応ガイドライン・参考資料)
   ├ 05_ticket.xlsx      write_ticket.py の出力(実ファイル名は 【案件名】(RITM…)アーキテクチャレビュー票(CSP).xlsx)
   ├ 06_answers.md       回答済み票の仕分け(2次用)
   └ 07_knowledge.md     【ナレッジ文案】
```

- 番号は工程の順。次の工程は前の番号のファイルを読む
- やり直すときは該当ファイルを消して再実行する(上書き前に `_prev` を付けて退避する運用でもよい)
- 2次チェックは `04_check.md` を `04_check_1st.md` に退避してから `/check2` を実行する

---

## 使い方(1案件の流れ)

1. 初回のみ: `pip install -r mcp_graph_ro/requirements.txt`、`mcp_graph_ro/config.json` を設定、VS Code でこのフォルダを開く(MCP が起動する)
2. `cases/<RITM>/input/` に構成図の画像を置く
3. チャットで `/mermaid`(画像を添付)→ `output/01_mermaid.md` を mermaid.live で描画して確認。直す所は「○○が足りない」と伝えて再生成
4. `/extract` → `02_inventory.md` を確認
5. `/judge` → 初回はブラウザでサインイン → MCP がスレッドを取得 → `03_hosting.md` を確認(要確認・ヒアリング文があればスレッドへ)
6. `/check` → `filter_checkpoints.py` が下書きを作り、エージェントが埋める → `verify.py` で検算 → `04_check.md` を確認。直す所は「No.13は記載ありが正しい」と伝えて再生成
7. `/ticket` → `05_ticket.json` → `write_ticket.py` で xlsx → 内容を確認して利用者へ送付(投稿は Webhook または手動)
8. 回答が返ったら `/answers` → `06_answers.md` → 構成図修正があれば 3 から、無ければ `/judge` → `/check2`
9. 完了したら `/knowledge` → `07_knowledge.md` を技術相談ナレッジ List に手動登録

複数案件を並行するときは `cases/` に案件フォルダを並べ、プロンプトに RITM を指定して切り替える。会話を新しくしても状態はファイルにあるので失われない。

## Git で管理するもの / しないもの

| 管理する | 管理しない(.gitignore) |
|---|---|
| `.github/`(エージェント・プロンプト・スキル・共通ルール)、`.vscode/mcp.json`、`mcp_graph_ro/server.py`・`requirements.txt`・`config.sample.json`、`scripts/`、`README.md` | `cases/`(案件データ)、`mcp_graph_ro/config.json`(実ID)、`~/.archreview/`(トークンキャッシュ)、`__pycache__/`。`reference/` は機密区分に応じて判断 |

## 前提(社内確認が必要なもの)

- GitHub Copilot(VS Code)に案件データ(構成図・Teams スレッド)を入力してよいか(AI利用ポリシー)
- 画像対応モデルが利用できるか(/mermaid に必要)
- VS Code で MCP サーバーとターミナル実行が許可されているか
- Microsoft Graph の委任権限(ChannelMessage.Read.All / Sites.Read.All)の承認(Global App Reg Tool で登録、既定外権限は Global CyberSecurity 承認+SSDLC)。承認前は `input/thread.md` を手動コピーで運用する
