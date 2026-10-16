# アーキテクチャレビューAgent 設計書(GitHub Copilot / VS Code 版)

- 版: 0.1(ドラフト) ｜ 作成日: 2026-10-16 ｜ 作成: CMS Eng
- 位置づけ: Copilot Studio 版(Ver.6.x)の設計を引き継ぎ、GitHub Copilot(VS Code)の特性を前提に再設計したもの。決定事項ではなく、PoC で検証しながら更新する
- 関連文書: 検討案(ArchReview_GitHubCopilot_Plan.docx)、リポジトリ README、Copilot Studio 版 設計書 Ver.6.2 / 設計原則・共通ルール Ver.6.2 / ツール一覧 / テスト手順書

---

## 1. 目的と範囲

### 1.1 目的
アーキテクチャレビュー業務(利用者から受領した構成図を、ホスティング環境の判定・構成図の観点チェック・アーキテクチャレビュー票の作成・回答の回収・2次チェック・ナレッジ登録まで)を AI で高度化する。目的は Copilot Studio 版と同じで、変わるのは実行基盤と設計の置き方だけ。

- 高度化の中身: 判定・チェック・票案の作成を AI が行い、Eng は確認と修正に集中する。判断の根拠(ID・観点No・ノードID)を常に残す
- 変えないこと: 出力はすべて案。確定・承認・利用者への連絡・ナレッジ登録は人が行う。参照データ(ノックアウト要件・観点表・テンプレート)は変更しない

### 1.2 範囲
| 区分 | 内容 |
|---|---|
| 対象 | 構成図Mermaid化 → 構成図情報抽出 → ホスティング判定 → 構成図チェック(1次) → アーキテクチャレビュー票作成(編集指示・Excel) → 回答回収 → 再判定 → 構成図チェック(2次) → ナレッジ文案 |
| 対象外 | 利用者との対話そのもの(Teams スレッドでのやり取りは人)、確定判断、ナレッジ List への登録操作、Mgmt の事前相談業務 |
| 将来の拡張候補 | Mgmt の事前相談業務(構成図が無い段階での要件ヒアリング・方針相談)。複雑度が高く可能性は低いが、15章の拡張方法で追加できる形にしておく |

### 1.3 用語
| 用語 | 意味 |
|---|---|
| 案件 / RITM | ServiceNow の RITM 番号で識別するレビュー1件。`cases/<RITM>/` が案件の状態 |
| 工程 | Mermaid化・抽出・判定・チェック・票作成・回答回収・ナレッジ文案の各段階。成果物ファイルの番号(01〜07)に対応 |
| エージェント | VS Code のカスタムエージェント(`.github/agents/*.agent.md`)。Copilot Studio 版の子Agentに相当 |
| 窓口エージェント(review) | 進捗を見て次の工程を案内し、ハンドオフで子エージェントへ切り替える。親Agentに相当 |
| スクリプト | `scripts/*.py`。決定的な処理(絞り込み・検算・Excel)。エージェントフロー T2/T4/T5 に相当 |
| graph-ro | 読み取り専用の Microsoft Graph MCP サーバー。Teams スレッドと SharePoint ファイルの取得 |

---

## 2. GitHub Copilot の特性と設計への反映

Copilot Studio 版で苦労した点(ツール直後の応答の不安定さ、30分で切れる会話、複数案件の並行不可、8,000字・「/」参照などの制約)は、GitHub Copilot では前提が違うため「避ける」のではなく「使う」設計にできる。特性ごとに、本設計でどう反映するかを先に整理する。

| # | GitHub Copilot の特性 | 設計への反映 | Copilot Studio 版での対応物・課題 |
|---|---|---|---|
| C1 | ワークスペース(ファイル)中心。エージェントはファイルを読み書きし、結果はディスクに残る | 案件の状態は会話ではなく `cases/<RITM>/` のファイルに持つ。工程の成果物は番号付きファイル。再開・並行・やり直しはファイル単位 | 会話に状態を持つため 30分タイムアウトと 1:1 チャット制約に縛られた |
| C2 | カスタムエージェント(役割・ツール・モデルを定義)、ハンドオフ(応答後に次のエージェントへ切り替えるボタン)、サブエージェント(`agents`) | 工程ごとに1エージェント。窓口 review がハンドオフで次工程を提示。ボタンを押すのが「人の確認」になる。サブエージェントは内部の補助に限定 | 親Agentの対応表と依頼文。1指示=1子=1回を指示文で強制していた |
| C3 | ターミナル実行と MCP。ツール結果を見て続行し、エラーなら直して再実行する(自己検証ループ) | 絞り込み・下書き・検算・Excel をスクリプトに。check は `verify.py` が通るまで直す。LLM は判定と文章だけ | 決定的処理をフローの式と指示文で実装し、ツール直後の応答が不安定だった |
| C4 | プロンプトファイル(`/コマンド`、`${input:…}`)、指示ファイル(`applyTo` でファイル種別ごとに自動適用)、スキル(必要時に読み込まれる手順書) | 入口は `/judge` などのプロンプト。出力形式・票の文体はファイル種別に紐づく指示ファイルで自動適用。スクリプトの使い方はスキル | 指示文1本に全部を書き、8,000字制限と「/」参照の貼り直しが発生 |
| C5 | モデルを工程ごとに選べる(優先順位付き配列) | Mermaid化は画像対応モデル、判定・チェックは推論の強いモデル、抽出は標準モデル。社内で許可されたモデルから指定 | モデルは選べない |
| C6 | 定義がすべてテキストファイル → Git で差分・レビュー・ロールバック。同じ入力で再実行して比較できる | エージェント・プロンプト・スクリプトを Pull Request で変更。`tests/golden/` に正解付き案件を置き、変更時に回帰テスト | 変更は画面の貼り替え。再現性の検証ができなかった |
| C7 | ワークスペース内の検索・ファイル参照(`#file`)で必要な材料だけを読む | 参照データ(観点表・KO要件)はツールで必要行だけ取り出す。依頼文に長文を貼らない | 子は親の会話全体を受け取り、材料の過不足で止まった |
| C8 | フック(プレビュー)で、編集・ツール実行の前後に処理を挟める | 任意: 成果物を書いた直後に検算スクリプトを自動実行。プレビュー機能のため採用は後で判断 | なし |
| C9 | 実行はEngのPC上。データの流れが「ローカルファイル ↔ モデル提供側」に限定される | 案件データはリポジトリに入れない(`.gitignore`)。M365 とのやり取りは読み取り専用 MCP に限定し、投稿・保存は人か Webhook | M365 内で完結していた(この点は Studio 版の長所) |

---

## 3. 設計原則・共通ルール

Copilot Studio 版の「設計原則・共通ルール Ver.6.2」を引き継ぎ、GitHub Copilot 向けに置き換えたもの。番号は本書内の参照用。

### 3.1 設計原則
| # | 原則 | 内容 |
|---|---|---|
| P1 | 状態はファイル、会話は使い捨て | 案件の状態・材料・成果物は `cases/<RITM>/` に置く。チャットは何度新しくしてもよい。チャット履歴に依存する設計をしない |
| P2 | 決定的な処理はスクリプト | 行の絞り込み・件数・検算・ファイル変換・Excel 書き込みは Python。LLM に数えさせない・写させない |
| P3 | LLM の仕事は判定と文章 | 記載の有無の判定、根拠の抽出、利用者向けの文案、要約。それ以外はツール |
| P4 | 1工程=1エージェント=1成果物 | 工程ごとにエージェントと成果物ファイルを1対1にする。工程をまたぐ処理はしない |
| P5 | 人の確認は工程の間に置く | 窓口 review のハンドオフボタンを押すのが確認。自動で次工程に進まない(サブエージェントは内部補助のみ) |
| P6 | 下書きを埋める方式 | 形式が決まった成果物は、スクリプトが見出し・固定部分・件数を埋めた下書きを作り、エージェントは [ ] を埋める。形が崩れない |
| P7 | 検算が通るまで終わらない | 成果物を書いたら `verify.py` を実行し、不一致なら直す(最大2回)。それでも合わなければ「要確認」に書いて止める |
| P8 | 読み取りと書き込みを分ける | M365 からの取得は読み取り専用 MCP。Teams への投稿・SharePoint への保存は人または Webhook スクリプト。書き込み権限を申請しない |
| P9 | 参照データは変更しない | KO要件・観点表・テンプレートは SharePoint を正とし、同期またはコピーで置く。判定ロジックの都合でデータを変えない |
| P10 | 根拠を残す | すべての判定に ID・観点No・ノードID・記載箇所を添える。推測で補わない |
| P11 | 出力はすべて案 | 確定・承認・利用者連絡・ナレッジ登録は人。エージェントは Teams に投稿しない |
| P12 | 変更は Git で | エージェント・プロンプト・スクリプトの変更は PR でレビューし、`tests/golden/` で回帰確認してから main に入れる |

### 3.2 共通ルール(`.github/copilot-instructions.md` に書く内容)
- 出力はすべて案。確定・承認・利用者連絡・ナレッジ登録は人が行う
- 推測で補わない。判断には根拠(ID・観点No・ノードID・記載箇所)を添える
- 検算の分母はスクリプトが出した件数。一致しないときは不一致のまま書き、「## 要確認」に「検算不一致」と書く
- 出力は Markdown。1行目は状態行(【名称】状態: 完了 / 要確認 / 失敗)、見出しは「## 」、内容は「- 」の箇条書きで1項目1行。表は使わない。区切りは全角「｜」。観点番号は「No.X」
- 成果物は `cases/<RITM>/output/` に番号付きで書く。上書きするときは既存を `_prev` 付きで退避する
- graph-ro は読み取り専用。Teams への投稿、SharePoint への書き込みはしない
- 作業過程・ツールの生出力は成果物に含めない。チャットには結論と要確認だけを短く返す

### 3.3 ファイル種別ごとの指示(`.github/instructions/*.instructions.md`、`applyTo` で自動適用)
| ファイル | applyTo | 内容 |
|---|---|---|
| `output-format.instructions.md` | `cases/**/output/*.md` | 状態行・見出し・箇条書き・区切り・No.X の書式。見出しの順は 11章の形式に従う |
| `ticket-style.instructions.md` | `cases/**/output/05_ticket.json` | 票の文体: 1文目に構成図で見つけた事実「構成図内に○○の記載がございますが」、続けて確認または依頼、必要なら技術的な理由。カテゴリ=対象サービス名、指摘概要=短い名詞句、ステータス=New、対応区分はテンプレートの値から |
| `python.instructions.md` | `scripts/**/*.py`, `mcp_graph_ro/**/*.py` | 標準ライブラリ優先、引数は argparse、終了コードで成否、ログに本文を出さない、Graph は GET のみ |

---

## 4. 全体構成

### 4.1 構成図
```
[Eng の PC]
  VS Code + GitHub Copilot(チャット = 窓口)
   │  エージェント選択: review(窓口)  /  プロンプト: /mermaid /extract /judge /check /check2 /ticket /answers /knowledge
   │
   ├─ カスタムエージェント  .github/agents/{review,diagram,extract,hosting,check,sheet}.agent.md
   │     ├─ ハンドオフ(次工程へのボタン)   ← 人の確認ポイント
   │     ├─ ターミナル ─→ scripts/*.py(絞り込み・下書き・検算・Excel・投稿)
   │     ├─ MCP graph-ro ─→ Microsoft Graph(GET のみ)─→ Teams スレッド / SharePoint ファイル
   │     └─ ファイル読み書き ─→ cases/<RITM>/{input,output}/
   │
   ├─ 指示ファイル(.github/copilot-instructions.md, .github/instructions/*.instructions.md)  … 自動適用
   ├─ スキル(.github/skills/*/SKILL.md)  … スクリプトの使い方
   └─ reference/(KO要件・観点表・テンプレート・Salus)  … SharePoint から同期/コピー

[M365 側(申請不要な部分)]
  OneDrive 同期: SharePoint Agent連携用/ ↔ reference/, cases/<RITM>/output/(票の受け渡し)
  Teams Workflows Webhook: 票・ヒアリング文の投稿(scripts/post_teams.py から POST)

[GitHub]
  リポジトリ(エージェント定義・スクリプト・テスト)。案件データは含めない
```

### 4.2 部品一覧
| 部品 | 置き場所 | 役割 | 変更者 |
|---|---|---|---|
| 共通ルール | `.github/copilot-instructions.md` | 全エージェント共通の厳守事項 | 保守担当(PR) |
| ファイル種別別の指示 | `.github/instructions/*.instructions.md` | 出力形式・票の文体・コーディング規約 | 保守担当(PR) |
| カスタムエージェント | `.github/agents/*.agent.md` | 工程ごとの役割・手順・出力・ツール・モデル・ハンドオフ | 保守担当(PR) |
| プロンプト | `.github/prompts/*.prompt.md` | Eng が呼ぶ入口。RITM 等の入力を受け取りエージェントに渡す | 保守担当(PR) |
| スキル | `.github/skills/*/SKILL.md` | スクリプト・MCP の使い方(いつ・どう・何が出るか) | 保守担当(PR) |
| スクリプト | `scripts/*.py` | 決定的処理 | 保守担当(PR) |
| MCP サーバー | `mcp_graph_ro/` | Graph 読み取り | 保守担当(PR)。`config.json` は各Eng |
| MCP 登録 | `.vscode/mcp.json` | サーバーの起動定義 | 保守担当(PR) |
| 参照データ | `reference/` | KO要件・観点表・テンプレート・Salus・リソース一覧 | SharePoint 側で管理、同期 |
| 案件データ | `cases/<RITM>/` | 材料と成果物(Git 管理外) | 各Eng |
| テスト | `tests/golden/<case>/` | 正解付きの案件(入力と期待出力) | 保守担当(PR) |

### 4.3 Copilot Studio 版との対応
| Copilot Studio 版 | GitHub Copilot 版 | 備考 |
|---|---|---|
| DTG_アーキテクチャレビュー親Agent(対応表・依頼文・次の操作) | review エージェント+プロンプト+ハンドオフ | 「次の操作」は review の案内とハンドオフボタンに置き換え |
| 構成図Mermaid化Agent_Diagram | diagram エージェント | 画像対応モデルを指定 |
| 構成図情報抽出Agent_Extract | extract エージェント | ほぼそのまま移植 |
| ホスティング判定Agent_Hosting | hosting エージェント(+ /knowledge) | T1 の3資料は MCP と reference/ から |
| 構成図チェック観点抽出Agent_Points | scripts/filter_checkpoints.py | エージェントではなくスクリプトに |
| 構成図チェックAgent_Check | check エージェント | 下書きを埋める+verify ループ |
| アーキテクチャレビュー票作成Agent_Sheet | sheet エージェント+write_ticket.py+read_answers.py | 票作成・修正・Excel・回答回収 |
| T1 ホスティング判定データ取得 | graph-ro.get_thread + reference/ko_requirements.md + reference/salus.md | |
| T2 構成図チェック観点取得(圧縮行・draft・points) | scripts/filter_checkpoints.py | 式を Python に |
| T3 レビュー票テンプレート取得 | reference/template_<CSP>.md(同期) | |
| T4 アーキテクチャレビュー票Excel作成 | scripts/write_ticket.py | |
| T5 回答済みアーキテクチャレビュー票取得 | graph-ro.get_file または同期 + scripts/read_answers.py | |
| 指示語(判定して / 構成図チェックして …) | /judge /check … | 7章 |
| 共通厳守事項 | copilot-instructions.md + instructions/*.md | 3章 |

---

## 5. 会話の窓口と工程の流れ

### 5.1 窓口(review エージェント)
- VS Code のチャットでエージェント「review」を選び、「RITM1234567 をレビューして」または「RITM1234567 の次へ」と入力する
- review は `cases/<RITM>/output/` のファイルの有無と各成果物の状態行(完了 / 要確認)を読み、進捗と次にやることを3行以内で案内し、次工程へのハンドオフボタンを出す
- Eng がボタンを押すと、対象エージェントに切り替わり、プロンプトが入力欄に入る(`send: false`)。Eng が内容を見て送信する。ここが「人の確認」
- review 自身は判定・チェック・票作成をしない(P4・P5)

### 5.2 ハンドオフとサブエージェントの使い分け
| 方式 | 使う場面 | 本設計での方針 |
|---|---|---|
| ハンドオフ(`handoffs`) | 工程の切り替え。応答後にボタンが出て、押すと別エージェント+プロンプトに切り替わる | 工程間はすべてハンドオフ。`send: false` でEngが送信する。1指示=1工程を担保 |
| サブエージェント(`agents`) | エージェントの中から別エージェントを呼び、結果を受け取る | 当面は使わない(`agents: []`)。将来「一括モード」を作るときに review から呼ぶ形を検討 |
| プロンプト直接(`/judge`) | 窓口を経由せず工程を直接実行 | 慣れたEng向けの近道。結果は同じ |

### 5.3 1案件の工程表
| # | 工程 | 入口 | エージェント | 入力(読むもの) | 処理 | 成果物 | 人の確認 | 次へ |
|---|---|---|---|---|---|---|---|---|
| 1 | Mermaid化 | /mermaid(画像添付) | diagram | input/構成図.png | 画像→Mermaid+注釈情報 | 01_mermaid.md | mermaid.live で描画し原図と比較。差分は「○○が足りない」で再生成 | 抽出 |
| 2 | 抽出 | /extract | extract | 01 | ノード・接続・NW情報の一覧化、検算R0 | 02_inventory.md | 一覧の過不足 | 判定 |
| 3 | 判定 | /judge | hosting | 02、Teamsスレッド(graph-ro)、reference/ko_requirements.md、salus.md | KO要件の全行判定、Salus照合、環境決定 | 03_hosting.md、input/thread.md | 要確認・ヒアリング文。必要ならスレッドへ質問 | チェック(1次) |
| 4 | チェック(1次) | /check | check | 04_points.md・04_draft.md(スクリプト生成)、01〜03、thread.md | 観点ごとの判定、下書きを埋める、verify | 04_check.md | 要人手確認・Eng目視確認。「No.Xは△△が正しい」で再生成 | 票作成 |
| 5 | 票作成 | /ticket | sheet | 03、04、reference/template_<CSP>.md | ①流用②添削③追記④不要、票JSON、Excel | 05_edit.md、05_ticket.json、xlsx | 編集指示と票の内容 | 送付(人) |
| 6 | 送付・回答待ち | — | — | — | Excel を Mgmt 経由で利用者へ(人)。Webhook で投稿も可 | — | — | 回答回収 |
| 7 | 回答回収 | /answers | sheet | 回答済み xlsx(graph-ro.get_file または同期) | 回答済み/未回答/要確認の仕分け、構成図修正の有無 | 06_answers.md | 構成図修正ありなら 1 へ | 再判定 |
| 8 | 再判定 | /judge | hosting | 02、06、スレッド | 回答を根拠に加えて再判定 | 03_hosting.md(置換、旧は _1st) | 同上 | チェック(2次) |
| 9 | チェック(2次) | /check2 | check | 2次の 04_points/04_draft、01〜03、06 | 同じ観点で再判定 | 04_check.md(置換、旧は _1st) | 解消状況 | ナレッジ文案 |
| 10 | ナレッジ文案 | /knowledge | hosting | 03、スレッド | 技術相談ナレッジ List の16項目 | 07_knowledge.md | 文案を確認し List へ手動登録 | 完了 |

### 5.4 複数案件・再開・やり直し
- 複数案件: `cases/` に案件フォルダを並べる。チャットは1つで RITM を言い換えて切り替えても、案件ごとにチャットセッションや VS Code ウィンドウを分けてもよい。状態はファイルなので、どの入口からでも同じ所から続く
- 翌日の再開: フォルダを開いて review に「RITMxxx の次へ」。貼り直しは不要
- やり直し: 直したい成果物を消すか `_prev` に退避して、その工程を再実行。前工程の成果物はそのまま使われる
- 修正指示: 「No.13は記載ありが正しい」「RDS が足りない」のように伝えると、エージェントは同じ工程を指摘反映で全体再出力する(差分だけにしない)。これは Copilot Studio 版の「修正」処理と同じ

---

## 6. エージェント設計

共通: フロントマターに `description` / `tools` / `model`(優先順位付き配列。社内で許可されたモデルから選ぶ)/ 必要に応じ `handoffs`。`agents: []`。本文は Copilot Studio 版の指示文(Ver.6.3)を移植し、ツール呼び出しの箇所だけ「graph-ro/…」「ターミナルで python scripts/…」に置き換える。書式は VS Code の更新で変わるため、着手時に公式ドキュメントで確認する。

### 6.1 review(窓口)
| 項目 | 内容 |
|---|---|
| 役割 | 進捗判定と次工程の案内。判定・チェック・票作成はしない |
| tools | `search`, `read`(読み取りのみ) |
| handoffs | Mermaid化へ(diagram)/ 抽出へ(extract)/ 判定へ(hosting)/ チェックへ(check)/ 票作成へ(sheet)/ 回答回収へ(sheet)/ ナレッジ文案へ(hosting)。各 `prompt` に RITM を含め、`send: false` |
| 入力 | `cases/<RITM>/output/` のファイル一覧と各ファイルの1行目(状態行) |
| 手順 | 1. RITM を特定(無ければ聞く) 2. 01〜07 の有無と状態行を読む 3. 無い最初の成果物の工程を「次」として案内。直前の成果物が 要確認 なら、その「## 要確認」を先に要約 4. 該当するハンドオフを提示 |
| 出力 | チャットに3行以内(進捗 / 次にやること / 注意)。ファイルは書かない |
| 禁止 | 成果物の生成・編集。推測で進捗を決めない(ファイルが無い=未実施) |
| 移植元 | 親Agent 指示文の「対応表」の次の操作部分。依頼文・厳守1〜5は不要になる |

### 6.2 diagram(構成図Mermaid化)
| 項目 | 内容 |
|---|---|
| 役割 | 構成図の画像を Mermaid と注釈情報に書き起こす。レビュー・評価はしない |
| tools | `edit`, `read` |
| model | 画像対応モデル(社内許可のもの) |
| 入力 | チャットに添付された画像(または `input/構成図.png` を Eng が添付) |
| 出力 | `01_mermaid.md`: 状態行、Mermaid コードブロック、## 注釈情報(原文) |
| 手順・禁止 | 現行の構成図Mermaid化Agent の指示文をそのまま(変更しない方針を維持)。ノードIDを短縮しない。読めない箇所は注釈に「判読不能」と書き推測しない |
| 移植元 | 01_Diagram(現行の指示文) |

### 6.3 extract(構成図情報抽出)
| 項目 | 内容 |
|---|---|
| 役割 | Mermaid からサービス一覧・除外ノード・NW情報・注釈・記載なし/方向不明を抽出する。判定しない |
| tools | `edit`, `read`, `runCommands`(検算R0の件数確認に `python scripts/count_nodes.py` を使ってもよい) |
| 入力 | `01_mermaid.md` |
| 出力 | `02_inventory.md`(11.1) |
| 手順 | 全ノードを一覧に入れる(除外は 利用者・インターネット・Global WAN 相当のみ)/ ID は変えない / 接続1本1行 / 推定CSP / 検算R0 = サービス一覧+除外 = ノード総数 |
| 移植元 | 02_Extract(ほぼそのまま) |

### 6.4 hosting(ホスティング判定・再判定・ナレッジ文案)
| 項目 | 内容 |
|---|---|
| 役割 | DCS Hub / DCS Disconnected を判定し【ホスティング判定結果】を書く。処理名 ナレッジ文案作成 のときは【ナレッジ文案】を書く |
| tools | `graph-ro/find_thread`, `graph-ro/get_thread`, `graph-ro/get_file`, `edit`, `read` |
| model | 推論の強いモデル |
| 入力 | `02_inventory.md`、Teams スレッド(find_thread → get_thread。取得結果は `input/thread.md` に保存。MCP 未承認期間は Eng が置いた thread.md を使う)、`reference/ko_requirements.md`、`reference/salus.md`。再判定では `06_answers.md` も |
| 手順 | KO要件を全行・行順に 該当/非該当/条件付き該当/候補/判定不能。記載が無い行は、備考に「AIは判断しない」「利用者に確認」がある行だけ 判定不能(利用者に質問)、それ以外は 非該当(記載なし)/ CSP はスレッド由来を正 / Salus 照合は status ごとに件数と全サービス名 / 状態 (a)該当あり→Disconnected・完了 (b)不確定あり→判定不能(見込み)・要確認 (c)全非該当→Hub・完了 / 検算 |
| 出力 | `03_hosting.md`(11.2)。ナレッジ文案は `07_knowledge.md`(11.6) |
| 禁止 | KO要件に無い要件を足さない。全行数を数え直さない(reference の行数はスクリプト `count_rows.py` の出力を使う) |
| 移植元 | 03_Hosting(2,500字の軽量版)。ツール部分のみ置き換え |

### 6.5 check(構成図チェック 1次・2次・修正)
| 項目 | 内容 |
|---|---|
| 役割 | 観点ごとに構成図の記載の有無を判定し、下書きの [ ] を埋めて【構成図チェック結果】を書く。設計の良し悪し・ホスティング判定・票作成はしない |
| tools | `runCommands`, `edit`, `read`, `search` |
| model | 推論の強いモデル |
| 入力 | `04_points.md`(判定材料)と `04_draft.md`(下書き)— いずれも `scripts/filter_checkpoints.py` が生成 / `01_mermaid.md` / `02_inventory.md` / `03_hosting.md`(環境・CSP) / `input/thread.md` / 2次は `06_answers.md` |
| 手順 | 1. `python scripts/filter_checkpoints.py <RITM> --env <Hub\|Disconnected> --csp <CSP> --phase <1次\|2次>` を実行(環境・CSP は 03 から) 2. 判定材料の各行を上から順に: トリガー(常時 / 存在: A/B / 回答: 項目=値)→ AI判定○は 記載あり/記載なし/方向不明/判定不能+根拠30字、△は 判定案+根拠で 要人手確認 → 区分表で区分(表示名: 問題なし / Eng目視確認 / 利用者へ依頼 / 票で確認 / 対象外 / 要人手確認) 3. 下書きの [区分] [判定と根拠] [対応] [NN] [No列挙] [文案] を埋める。見出し・行順・固定部分は変えない 4. `python scripts/verify.py <RITM>` を実行し、不一致または [ ] 残りがあれば直して再実行(最大2回)。それでも残れば「## 要確認」に書く 5. `04_check.md` として保存 |
| 出力 | `04_check.md`(11.3)。チャットには結論と「次にEngがやること」だけ |
| 禁止 | 判定材料の行を成果物に転記しない。行を増減しない(足してよいのは 利用者への確認・依頼 と 要確認 のみ)。観点を足さない・減らさない |
| 移植元 | 04_Check(下書きを埋める版)。ツール呼び出しをスクリプト実行に置き換え、verify ループを追加 |

### 6.6 sheet(票作成・修正反映・Excel・回答回収)
| 項目 | 内容 |
|---|---|
| 役割 | 処理名に応じて 編集指示作成 → 修正反映 → Excel 生成 → 回答回収 を行う |
| tools | `runCommands`, `edit`, `read`, `graph-ro/get_file`, `graph-ro/list_folder` |
| 入力 | `03_hosting.md`、`04_check.md`、`reference/template_<CSP>.md`(票テンプレートの行。全行数は `count_rows.py`)。回答回収は回答済み xlsx |
| 手順(票作成) | テンプレート全行を ①流用 ②添削 ③追記 ④不要 に仕分け。反映順: (a)判定環境・Salus照合 → 該当行を②、無ければ③ (b)04_check の「利用者への確認・依頼」の各行(No.X(票No: Y)｜カテゴリ｜指摘概要｜指摘内容)→ 票No があれば②、無ければ③。Eng目視確認は票に入れない (c)見直し(回答・指摘の反映)。検算R2: ①+②+④ = 全行数 |
| 手順(Excel) | `05_ticket.json`(キー8つ: No. / ステータス / 環境 / 対応区分 / カテゴリ / 指摘概要 / 指摘内容 / 対応ガイドライン・参考資料。ステータスは New)を書き、`python scripts/write_ticket.py <RITM> <CSP>` を実行。検算R3: 書き込み件数 = ①+②+③ |
| 手順(回答回収) | `python scripts/read_answers.py <RITM> <xlsxパス>` で行を取り出し、回答済み / 未回答 / 要確認 に仕分け。構成図修正の有無を判定。検算R4 |
| 出力 | `05_edit.md`(【編集指示】11.4)、`05_ticket.json`、xlsx、`06_answers.md`(【回答回収結果】11.5) |
| 禁止 | 回答の可否・解消の判断はしない(Eng)。参考資料URLを推測で作らない(テンプレートにあるものだけ) |
| 移植元 | 05_Sheet。ツール T3/T4/T5 を reference・スクリプトに置き換え |

---

## 7. プロンプト・スキル設計

### 7.1 プロンプト(入口)
| ファイル | 呼び方 | agent | 入力変数 | 渡す内容(要旨) |
|---|---|---|---|---|
| `mermaid.prompt.md` | /mermaid + 画像 | diagram | ritm | RITM の構成図を Mermaid 化し 01_mermaid.md に保存。レビュー不要 |
| `extract.prompt.md` | /extract | extract | ritm | 01 から 02_inventory.md を作る |
| `judge.prompt.md` | /judge | hosting | ritm, phase(判定/再判定) | スレッド取得→判定→03_hosting.md。チャットには要確認とヒアリング文だけ |
| `check.prompt.md` | /check | check | ritm | 1次チェック→04_check.md。チャットには結論と次にやることだけ |
| `check2.prompt.md` | /check2 | check | ritm | 2次チェック(06 を材料に加える) |
| `ticket.prompt.md` | /ticket | sheet | ritm, csp | 票作成→05_edit.md / 05_ticket.json → Excel |
| `answers.prompt.md` | /answers | sheet | ritm, file | 回答済み票の取り込み→06_answers.md |
| `knowledge.prompt.md` | /knowledge | hosting | ritm | ナレッジ文案→07_knowledge.md |

- プロンプトには「どのファイルを読み、どのファイルに書き、チャットに何を返すか」だけを書く。手順はエージェント側に置く(重複させない)
- `${input:ritm:RITM1234567}` のように既定値を付け、入力漏れを防ぐ

### 7.2 スキル(手順書)
| スキル | 対象 | 内容 |
|---|---|---|
| `checkpoint-filter` | scripts/filter_checkpoints.py | /check の最初に必ず実行。引数、出力(04_points / 04_draft / 適用行数)、観点表の列の意味 |
| `verify` | scripts/verify.py | 成果物ごとの検算の種類(R0〜R4)、終了コード、不一致時の扱い |
| `ticket-excel` | scripts/write_ticket.py | 票JSONのキー、テンプレートの場所、出力ファイル名 |
| `graph-tool` | mcp_graph_ro | find_thread → get_thread の順、チャネルキー、取得結果の保存先、未承認期間の代替(手動コピー) |
| `teams-post` | scripts/post_teams.py | Webhook URL の置き場所(環境変数)、投稿文の形、投稿は人が確認してから |

---

## 8. スクリプト設計

共通: Python 3.11+、標準ライブラリ優先(Excel は openpyxl)。引数は argparse。成功 0 / 検算不一致 1 / 入力不備 2 の終了コード。本文をログに出さない。入出力は `cases/<RITM>/` と `reference/` のみ。

| スクリプト | 目的(旧ツール) | 引数 | 入力 | 出力 | エラー時 |
|---|---|---|---|---|---|
| `filter_checkpoints.py` | 観点の絞り込みと下書き生成(T2) | ritm, --env, --csp, --phase | reference/checkpoints.md | 04_points.md(1観点1行: No｜観点｜トリガー｜AI判定｜方法｜区分表｜出力)、04_draft.md(11.3 の下書き)、標準出力に適用行数 | 適用0行なら終了コード2と「条件を確認」 |
| `verify.py` | 検算(全成果物) | ritm [--target 02\|03\|04\|05\|06] | 対象の成果物と分母(04_points の適用行数、reference の行数、票の行数) | 一致/不一致、未記入 [ ] の件数と例 | 不一致で終了コード1 |
| `count_rows.py` | 参照データの行数(T1/T3 の「全行数」) | ファイルパス | reference/*.md | 表のデータ行数 | — |
| `write_ticket.py` | 票JSON→Excel(T4) | ritm, csp | 05_ticket.json、reference のテンプレート xlsx | 【案件名】(RITM)アーキテクチャレビュー票(CSP).xlsx、書き込み件数 | キー不足で終了コード2 |
| `read_answers.py` | 回答済み票の読み取り(T5) | ritm, xlsxパス | 回答済み xlsx | 06_answers_rows.md(No｜指摘概要｜回答 の1行1件。sheet が仕分けの材料にする)、全行数 | 列名不一致で終了コード2 |
| `post_teams.py` | Teams へ投稿(Workflows Webhook) | ritm, --text ファイル | 投稿文、環境変数 TEAMS_WEBHOOK_URL | 投稿結果 | HTTP エラーで終了コード1。Graph は使わない |
| `new_case.py` | 案件フォルダ作成 | ritm | — | cases/<RITM>/{input,output}/ | 既存なら何もしない |

---

## 9. MCP サーバー設計(graph-ro)

### 9.1 方針
- 読み取り専用。Graph API は GET のみ。POST/PATCH/DELETE をコードに含めない(審査で「存在しない」と示せる)
- 委任権限。Eng 本人のサインインで、本人が見られる範囲だけにアクセス
- 対象のチーム・チャネル・サイトは `config.json` の許可リストに固定。リスト外はエラー
- 書き込みが将来必要になっても、このサーバーには足さず、別サーバー(graph-rw)として分ける

### 9.2 認証とトークン
| 項目 | 設計 |
|---|---|
| ライブラリ | MSAL for Python(PublicClientApplication) |
| フロー | 認可コード+PKCE(ブラウザでサインイン、リダイレクト http://localhost:<port>)。ブラウザ不可の環境はデバイスコード。暗黙フローは使わない(KB「④トークン直接呼出し」で不許可) |
| キャッシュ | msal-extensions で暗号化(Windows DPAPI)し `~/.archreview/token_cache.bin` に保存。サインインは初回と期限切れ時のみ |
| 登録種別 | パブリッククライアント(モバイル/デスクトップ)を第一候補。Global App Reg Tool で選べない場合は Web+シークレット(ConfidentialClient、資格情報ストア保管、KB Q8 の期限管理) |
| スコープ | ChannelMessage.Read.All / Sites.Read.All / User.Read / offline_access(任意: Team.ReadBasic.All / Channel.ReadBasic.All) |

### 9.3 ツール仕様
| ツール | 引数 | 戻り値 | Graph API |
|---|---|---|---|
| find_thread | channel_key(config のキー), ritm | 一致する親投稿の一覧(messageId｜投稿者｜日時｜冒頭80字) | GET /teams/{team}/channels/{channel}/messages(ページング、上限300件) |
| get_thread | channel_key, message_id | 親投稿+全返信を時系列の Markdown(見出し: 親投稿 / 返信N ｜ 投稿者 ｜ 日時) | GET …/messages/{id}, GET …/messages/{id}/replies |
| list_folder | site_key, path | フォルダ一覧([D]/[F] 名前 サイズ) | GET /sites/{site}/drive/root:/{path}:/children |
| get_file | site_key, path | md/txt/csv は本文、それ以外は cases/_downloads/ に保存してパス | GET /sites/{site}/drive/root:/{path}:/content |
| find_channel(将来) | team名, チャネル名 | team_id / channel_id | GET /teams/{team}/channels |

### 9.4 設定(config.json)
tenant_id / client_id / redirect_port / auth_flow(interactive | devicecode)/ channels{キー: {team_id, channel_id}} / sites{キー: {site_id, base_path}} / download_dir。実IDの入った config.json は Git 管理外、`config.sample.json` を管理する。

### 9.5 ログ・エラー
- ログはツール名・引数のキー・件数・所要時間のみ。本文・ファイル内容は出さない
- 401/403 はサインイン再実行を促すメッセージ、404 は「許可リストとパスを確認」、429 は待って1回再試行

---

## 10. データ設計

### 10.1 参照データ(reference/)
| ファイル | 由来(SharePoint) | 使う工程 | 主な列・内容 |
|---|---|---|---|
| ko_requirements.md | ノックアウト要件一覧 | 判定 | ID / No. / 要因 / 具体的なケース / 判断区分 / 備考 |
| salus.md | Salus Status 一覧 | 判定 | サービス名 / status(TRUE/FALSE) ほか |
| checkpoints.md | 構成図チェック観点 | チェック(スクリプト) | [1]No [2]大分類 [3]チェック観点 [4]判断基準 [5]対象CSP [6]環境 [7]テンプレート対象No [8]AI判定可否 [9]チェックタイミング [10]判定トリガー [11]ネクストアクション [12]AI判定方法 [13]AI出力内容 [14]備考。本表は `<!-- 参照シート ここから -->` より前 |
| template_<CSP>.md(実体: 【案件名】(RITMxxxxxxx)アーキテクチャレビュー票(<CSP>).md) | 票テンプレート | 票作成 | 票の行(No. / 環境 / 対応区分 / カテゴリ / 指摘概要 / 指摘内容 / 対応ガイドライン・参考資料) |
| 【案件名】(RITMxxxxxxx)アーキテクチャレビュー票(CSP名).xlsx | Excel 雛形 | Excel 生成 | 1行目が見出し |
| service_resources.md(将来) | サービス提供対象リソース一覧 | 票作成(申し送り) | サービス名 / 利用者による動作検証必要 ほか |

- 更新は SharePoint 側で行い、同期で取り込む(P9)。リポジトリに置けない機密区分なら `reference/` を Git 管理外にする

### 10.2 案件データ(cases/<RITM>/)
| パス | 内容 | 作る人/物 |
|---|---|---|
| input/構成図.png | 利用者から受領した構成図 | Eng |
| input/thread.md | Teams スレッド本文 | graph-ro.get_thread(未承認期間は Eng が手動) |
| output/01_mermaid.md | 確定図(Mermaid+注釈情報) | diagram |
| output/02_inventory.md | 【構成図一覧】 | extract |
| output/03_hosting.md | 【ホスティング判定結果】(再判定で置換。旧は 03_hosting_1st.md) | hosting |
| output/04_points.md / 04_draft.md | 判定材料 / 下書き(2次は _2nd 付きで別名) | filter_checkpoints.py |
| output/04_check.md | 【構成図チェック結果】(2次で置換。旧は 04_check_1st.md) | check |
| output/05_edit.md | 【編集指示】 | sheet |
| output/05_ticket.json | 票の行(JSON 配列、キー8つ) | sheet |
| output/【案件名】(RITM)アーキテクチャレビュー票(CSP).xlsx | 送付する票 | write_ticket.py |
| output/06_answers.md | 【回答回収結果】 | sheet(read_answers.py の出力を材料に) |
| output/07_knowledge.md | 【ナレッジ文案】 | hosting |
| _downloads/ | get_file が保存したバイナリ | graph-ro |

- `cases/` は `.gitignore`。案件データをリポジトリに入れない(C9)
- 上書き前の退避は `_prev`、1次/2次の区別は `_1st`。退避ファイルは次工程の材料にしない

### 10.3 状態行と検算の約束
- すべての成果物の1行目は `【名称】状態: 完了 | 要確認 | 失敗`。review はこの行だけで進捗を判断する
- 検算は成果物の末尾「## 検算」に書き、`verify.py` が同じ式で確認する: R0(一覧)= サービス一覧+除外 = ノード総数 / R1(判定)= 非該当+個別 = KO全行数、TRUE+FALSE+未照合 = サービス件数 / R2(票)= ①+②+④ = テンプレート全行数 / R3 = 書き込み件数 = ①+②+③ / R4(回答)= 回答済み+未回答+要確認 = 全行数 / チェック = 6区分合計 = 適用行数

---

## 11. 出力形式

Copilot Studio 版 Ver.6.3 の形式を踏襲する。変更点は「構成図チェック結果」の新形式(結論が先・観点名付きサマリ・票の文案)と、票作成の文案行の形式。

### 11.1 【構成図一覧】(02_inventory.md)
状態行 → ## 基本情報(RITM / 推定CSP(根拠ノード)) → ## サービス一覧(NN件)(ノードID｜表示ラベル｜正式名｜配置)→ ## 除外ノード(NN件)→ ## NW情報(リージョン / VNet・VPC / サブネット(AZ)/ CIDR原文 / 通信経路 1接続1行)→ ## 注釈情報(原文)→ ## 記載なし・方向不明 → ## 要確認 → ## 検算(R0)

### 11.2 【ホスティング判定結果】(03_hosting.md)
状態行 → ## 判定(RITM / CSP / 判定環境 / 判定理由)→ ## ノックアウト要件 照合(全NN行)(非該当(NN件): ID列挙 / 個別行: ID｜判断区分｜結果｜根拠)→ ## Salus照合(サービス一覧NN件)(TRUE / FALSE / 未照合 ごとに件数と全サービス名)→ ## 要確認(Eng判断)→ ## ヒアリング文(利用者向け)→ ## 検算(R1)

### 11.3 【構成図チェック結果】(04_check.md。下書きはスクリプトが生成)
```
【構成図チェック結果】状態: 完了 | 要確認
## このチェックについて
- 処理: 1次チェック(…) | 2次チェック(…) ｜ RITM ｜ 環境: ｜ CSP:
- 関わる観点: NN件
- 結論: 対応が必要 NN件(票で確認NN・利用者へ依頼NN・Eng目視確認NN・要人手確認NN)、問題なし NN件、対象外 NN件
- 次にEngがやること: 1〜2文
- 区分の意味: 問題なし=… ｜ 票で確認=… ｜ 利用者へ依頼=… ｜ Eng目視確認=… ｜ 要人手確認=… ｜ 対象外=…
## 結果サマリ
- 票で確認(NN件): No.X 観点名, …
- 利用者へ依頼(NN件): …   - Eng目視確認(NN件): …   - 要人手確認(NN件): …
- 問題なし(NN件): No.X, …   - 対象外(NN件): No.X(利用なし / 回答なし), …
## 利用者への確認・依頼(票の指摘内容の文案)
- No.X(票No: Y)｜カテゴリ: サービス名｜指摘概要: 件名｜指摘内容: 文案
## 観点ごとの判定(No順。1観点1行)
- No.X 観点名 → 区分(票No: Y)｜確認ポイント: 判断基準｜構成図の状態: 判定と根拠｜次の対応: …
## 要確認
## 検算
- 票で確認NN + 利用者へ依頼NN + Eng目視確認NN + 要人手確認NN + 問題なしNN + 対象外NN = NN(適用行数 NN と一致)
```

### 11.4 【編集指示】(05_edit.md)
状態行 → ## 条件(RITM / CSP / テンプレート: ファイル名(全行数NN))→ ## ①流用(No｜指摘概要)→ ## ②添削(No｜指摘概要｜修正後の指摘内容｜理由)→ ## ③追記(No｜環境｜対応区分｜カテゴリ｜指摘概要｜指摘内容｜対応ガイドライン・参考資料｜理由)→ ## ④不要(No｜指摘概要｜理由)→ ## 検算(R2)→ ## 要確認。票本体は 05_ticket.json(キー8つ)

### 11.5 【回答回収結果】(06_answers.md)
状態行(完了(すべて解消)| 要確認 | 未着)→ ## 集計(構成図修正: あり/なし / RITM / 対象ファイル / 回答済みNN・未回答NN・要確認NN(全NN行))→ ## 未回答 → ## 要確認 → ## 回答済み → ## 検算(R4)

### 11.6 【ナレッジ文案】(07_knowledge.md)
状態行 → ## 文案(16項目を「- 番号 項目名: 値」。確定できない項目は (未記入)。選択肢は完全一致の値)→ ## 要確認

---

## 12. 運用設計

### 12.1 Eng の操作(標準)
1. 新規案件: `python scripts/new_case.py RITMxxxxxxx` → `input/` に構成図を置く
2. review に「RITMxxxxxxx をレビューして」→ 案内に従いハンドオフ → 各工程の成果物を確認
3. 成果物を直すときは、そのエージェントに「No.13は記載ありが正しい」のように伝えて全体再出力(ファイルを直接編集してもよいが、再生成した場合に消えるので要確認に理由を残す)
4. 票を送付(Excel を Mgmt 経由で利用者へ。ヒアリング文は Teams スレッドへ投稿: 手動または `post_teams.py`)
5. 回答が来たら `/answers` → 構成図修正があれば 1 へ、無ければ `/judge` → `/check2`
6. `/knowledge` → 文案を確認して技術相談ナレッジ List に手動登録 → 完了

### 12.2 人の確認ポイント(省略しない)
| 工程後 | 確認すること |
|---|---|
| Mermaid化 | mermaid.live で描画し原図と一致。ノードの欠落・接続の向き |
| 抽出 | サービス一覧の過不足、除外の妥当性、R0 一致 |
| 判定 | 判定環境と決め手、要確認の行、ヒアリング文の内容(利用者に送る前) |
| チェック | 要人手確認・Eng目視確認の観点、利用者への確認・依頼の文案(票に入る)、検算一致 |
| 票作成 | ②添削・③追記の内容、④不要の理由、Excel の見た目、【案件名】の記入 |
| 回答回収 | 要確認の行、構成図修正の有無の判断 |

### 12.3 Teams への投稿
- 原則は人が投稿する(現行どおり)。自動化する場合は Teams Workflows Webhook(申請が軽い)を `post_teams.py` から使い、投稿前にチャットで本文を Eng が確認する
- Graph の投稿権限(ChannelMessage.Send)は申請しない(P8)

### 12.4 保守
- エージェント・プロンプト・スクリプトの変更は PR。レビューは Eng 2名以上。マージ前に 14章の回帰テストを実行
- 参照データの変更は SharePoint 側。変更があったら `tests/golden/` の期待出力を見直す
- 四半期に1回、エージェント定義の書式(フロントマター)が VS Code の最新仕様に合っているか確認

### 12.5 Entra ID アプリの運用
- Requestor は担当 Eng(変更は KB Q7 の手順)。シークレットを持つ構成の場合は KB Q8 のアラートに従い更新
- 棚卸(KB 3章): 13か月未使用で無効化されるため、PoC 終了時に継続か削除かを決める

---

## 13. セキュリティ・権限

### 13.1 データの置き場所と流れ
| データ | 置き場所 | 流れる先 |
|---|---|---|
| 構成図・スレッド・成果物(案件データ) | Eng の PC `cases/`(Git 管理外) | GitHub Copilot のモデル提供側(推論のため)。社内 AI 利用ポリシーで可否を確認 |
| 参照データ | `reference/`(SharePoint 同期) | 同上 |
| トークン | `~/.archreview/token_cache.bin`(暗号化) | 外に出ない |
| エージェント定義・スクリプト | GitHub リポジトリ | — |

### 13.2 Graph 権限と申請(社内KB「Microsoft Entra ID アプリケーション登録、SSO設定、サービスプリンシパル設定」に沿う)
| 項目 | 内容 | KB の箇所 |
|---|---|---|
| 登録の前提 | TOM審査・情報システム導入審査 → CMDB登録 | 2. 登録フロー ステップ① |
| 登録 | Global App Reg Tool で所管チーム(CMS Eng)が登録 | 2. ステップ② |
| 権限の種類 | 委任(ユーザ委任のAPIアクセス許可 = Scope)。アプリケーション権限は使わない | ① Graph API 及びその他 API 権限設定 |
| 既定で承認済み | User.Read / openid / offline_access など9権限 | 5-3 サービスプリンシパルの権限設定 |
| 追加申請が必要 | ChannelMessage.Read.All / Sites.Read.All(/ Team.ReadBasic.All / Channel.ReadBasic.All)。Global CyberSecurity 承認+SSDLC(CheckPoint II) | 5-3 / ① / FAQ Q3 / 日本語マニュアル 5.3.3 |
| トークン | MSAL 利用アプリは有効化不要。暗黙フロー不許可 | ④ トークン直接呼出しの有効化 |
| 運用 | Requestor 変更(Q7)、資格情報期限(Q8)、棚卸(3章)、問い合わせ(8章) | 各該当箇所 |

### 13.3 読み取り専用の担保
- graph-ro に GET 以外の呼び出しが無いことをコードレビューで確認(PR テンプレートにチェック項目)
- 許可リスト外のチーム・サイトはエラー
- 書き込みは `post_teams.py`(Webhook)と人の操作だけ

---

## 14. テスト・評価設計

### 14.1 正解付き案件(tests/golden/)
```
tests/golden/<case名>/
├ input/   構成図.png  thread.md
├ reference_snapshot/   そのときの観点表・KO要件(版を固定)
└ expected/ 02_inventory.md  03_hosting.md  04_check.md  05_edit.md   … 人が確認した正解
```
- 最低3件(AWS/Azure/GCP で1件ずつ、うち1件は Disconnected 判定になるもの)
- `python scripts/eval.py <case名>` で、実行結果と expected の「比較する項目」だけを突き合わせる: 判定環境、KO要件の該当ID、Salus の TRUE/FALSE 件数、観点ごとの区分、票の①②③④の No。文章の一致は求めない

### 14.2 工程ごとの確認項目
| 工程 | 確認 | 合格基準(PoC) |
|---|---|---|
| 抽出 | ノード欠落ゼロ、R0 一致 | 3件すべて一致 |
| 判定 | 判定環境が正解と一致、該当IDが一致 | 3件すべて一致 |
| チェック | 6区分の合計 = 適用行数、観点表の転記ゼロ、[ ] 残りゼロ、区分の一致率 | 検算100%、区分一致 90%以上 |
| 票作成 | R2・R3 一致、文案が票の文体 | 検算100%、Eng の修正が行の3割以下 |
| 安定性 | 同じ入力で3回実行し、比較項目の一致率 | 95%以上 |

### 14.3 回帰テスト
- エージェント・プロンプト・スクリプトを変更する PR では、`eval.py` を golden 全件に実行し、結果を PR に貼る
- 参照データが変わったら golden の reference_snapshot と expected を更新する(データ変更の影響範囲が見える)

---

## 15. 拡張性(将来の工程追加)

Mgmt の事前相談業務のように工程を足す場合の手順。既存のエージェントは変更しない。
1. 成果物の番号を決める(事前相談なら 00_consult.md のように先頭、または 08 以降)
2. `.github/agents/<name>.agent.md` を追加(役割・入力・手順・出力・ツール)
3. `.github/prompts/<name>.prompt.md` を追加
4. review の `handoffs` に1行追加し、進捗判定の順序に成果物を加える
5. 必要な参照データを `reference/` に追加(SharePoint 側で管理)
6. 検算があれば `verify.py` に式を追加し、`tests/golden/` に正解を追加
- 事前相談は構成図が無い段階で要件を聞き取る性質上、Teams スレッドの読み取りと要件の構造化(質問票の生成)が中心になる。graph-ro と hosting の KO要件判定を部品として再利用できる

---

## 16. 未決事項・後回し
| # | 事項 | 影響 | 決め方 |
|---|---|---|---|
| 1 | GitHub Copilot に案件データを入力してよいか(AI利用ポリシー) | 本案の成否 | Phase 0 で確認 |
| 2 | Global App Reg Tool でパブリッククライアントとして登録できるか | 認証方式・シークレット管理 | 申請時に確認 |
| 3 | PoC 用ツールでも TOM審査・導入審査が必須か | 申請期間 | IT に確認 |
| 4 | 画像対応モデルの利用可否 | Mermaid化の実現方法(不可なら Copilot Studio に残す) | Phase 0 |
| 5 | Teams Workflows Webhook の利用可否 | 投稿の自動化(不可なら手動) | Phase 4 |
| 6 | フック(プレビュー)で検算を自動化するか | 運用の手間 | Phase 4 以降、機能が GA してから |
| 7 | 申し送り(サービス提供対象リソース一覧)の票反映 | 票の③追記 | Phase 4 |
| 8 | 一括モード(サブエージェントで Mermaid化〜チェックを連続実行) | 操作回数 | 安定性が確認できてから |
| 9 | Web UI(Eng 以外が触る窓口) | 利用者・Mgmt の利便性 | 別プロジェクトとして判断 |

---

## 付録A. 指示語の対応(Copilot Studio 版 → GitHub Copilot 版)
| Copilot Studio 版の指示語 | GitHub Copilot 版 |
|---|---|
| RITMxxx 添付した構成図をMermaid化して | /mermaid(画像添付) |
| RITMxxx Mermaidを貼り付けます | 01_mermaid.md に貼って保存 |
| 抽出して | /extract |
| 判定して / 再判断して | /judge(phase=判定 / 再判定) |
| 観点を取得して / 2次の観点を取得して | 不要(check が filter_checkpoints.py を実行) |
| 構成図チェックして / 2次チェックして | /check / /check2 |
| レビュー票を作成して / レビュー票を見直して | /ticket(見直しは「指摘」を添えて同じ) |
| Excelを作成して | /ticket の中で write_ticket.py が実行(分けたい場合は /excel を追加) |
| 回答を確認して | /answers |
| ナレッジ文案を作成して | /knowledge |
| 環境は○○で進めて / CSPは○○で進めて | /check や /ticket の入力変数で指定(03_hosting.md を直してもよい) |
| 直前の子の出力への指摘(No.5は不要 など) | 同じエージェントに指摘を伝える(全体再出力) |

## 付録B. 用語・略語
DCS Hub / DCS Disconnected(ホスティング環境)、KO要件(ノックアウト要件)、Salus(サービス提供可否の一覧)、RITM(ServiceNow の要求項目番号)、PKCE(認可コードフローの拡張)、MSAL(Microsoft Authentication Library)、MCP(Model Context Protocol)、SSDLC(Secure Software Development Life Cycle)、Global App Reg Tool(Deloitte Microsoft Entra Application Registration Tool)
