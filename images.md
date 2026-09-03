%%{init: {"theme": "base", "themeVariables": {"edgeLabelBackground": "#ffffff00", "lineColor": "#5a5a5a", "fontSize": "13px"}}}%%
flowchart TD
    subgraph P0["Phase 0: 前提(人間のみ)"]
        A["<b>Mgmt</b><br>DCS利用の一次判断・判定アプリ実行<br>結果をスレッドへ投稿→Engへ引継ぎ"]:::human
    end

    subgraph P1["Phase 1: レビュー開始"]
        B["<b>Eng</b><br>親へ「RITMxxxxxxxをレビューして」<br>+構成図画像を添付"]:::human
        O1a["<b>親</b> Engから指示文+画像を受領<br>指示を「レビュー開始」と判定、RITM番号を抽出・半角正規化、画像の有無を確認<br>→ 子Aを呼び出し(渡す: 構成図画像+RITM番号)"]:::parent
        CA1["<b>子A</b> 構成図情報抽出<br>ツール②観点取得→画像読取→CSP推定(図内記載のみ根拠)<br>→観点別チェック→検算R1"]:::child
        O1b["<b>親</b> 子Aから【構成図チェック結果】を受領し原文のまま保持<br>→ 子Bを呼び出し(渡す: RITM番号+抽出結果+Engの補足)<br>※スレッド本文は渡さない(子Bが自分で取得)"]:::parent
        CB1["<b>子B</b> ホスティング判定<br>ツール①スレッド取得→③ノックアウト要件→④Salus・検証状況<br>→1件ずつ照合→判定+理由+追加ヒアリング文案"]:::child
        O1c["<b>親</b> 子Bから判定結果を受領し原文のまま保持<br>図由来CSPとスレッド由来CSPを突合(不一致はEngへ確認)<br>→ Engへ判定結果を提示(ヒアリング文案があれば次アクションも案内)"]:::parent
        D{"<b>Eng</b><br>判定結果を確認"}:::decision
    end

    subgraph P2["Phase 2: 追加ヒアリング〜再判断(複数回あり)"]
        GH["<b>Eng</b><br>ヒアリング文案を確認・修正→Mgmtへ"]:::human
        GM["<b>Mgmt</b><br>利用者へヒアリング→回答をスレッドへ反映→Engへ連絡"]:::human
        E2["<b>Eng</b><br>親へ「再判断して」"]:::human
        O2a["<b>親</b> Engから指示文を受領<br>指示を「再判断」と判定(Engに再入力させない)<br>→ 子Bを呼び出し(渡す: 保持済みのRITM番号+抽出結果)"]:::parent
        CB2["<b>子B</b> 再判定<br>ツール①で最新スレッド(利用者回答を含む)を再取得<br>→③④→再照合→判定を更新"]:::child
    end

    subgraph P3["Phase 3: アーキテクチャレビュー票作成"]
        E3["<b>Eng</b><br>親へ「レビュー票を作成して」"]:::human
        O3a["<b>親</b> Engから指示文を受領<br>指示を「レビュー票作成」と判定<br>→ 子Cを呼び出し(渡す: RITM番号+判定結果) ※スレッド本文は渡さない"]:::parent
        CC1["<b>子C</b> 編集指示+票md作成<br>ツール①スレッド取得→⑤票md取得(全NN行)<br>→①流用②添削③追記④不要→検算R2→票md"]:::child
        O3b["<b>親</b> 子Cから編集指示・票mdを受領し「案」として保持<br>→ Engへ原文のまま提示"]:::parent
        E3b{"<b>Eng</b><br>編集指示を確認"}:::decision
        O3c["<b>親</b> Engから修正点を受領<br>→ 子Cを再呼び出し(渡す: 前回の編集指示+Engの修正点)"]:::parent
        O3d["<b>親</b> Engから「確定」を受領<br>→ その時点の編集指示を確定版として保持"]:::parent
    end

    subgraph P4["Phase 4: 構成図修正案"]
        E4["<b>Eng</b><br>親へ「修正モードを実行して」"]:::human
        O4a["<b>親</b> Engから指示文を受領<br>指示を「構成図修正案」と判定、3材料が揃っているか確認<br>→ 子Dを呼び出し(渡す: 材料1 抽出結果+材料2 判定結果+材料3 確定版編集指示)"]:::parent
        CD1["<b>子D</b> 構成図修正指示(案)作成<br>材料2・3で決まったことのうち<br>材料1の時点で図に無い・誤っているもの=修正指示"]:::child
        O4b["<b>親</b> 子Dから修正指示(案)を受領し保持<br>→ Engへ原文のまま提示"]:::parent
        E4b["<b>Eng</b><br>修正指示(案)を確認・修正"]:::human
    end

    subgraph P5["Phase 5: 送付用Excel生成"]
        E5["<b>Eng</b><br>親へ「Excelを作成して」"]:::human
        O5a["<b>親</b> Engから指示文を受領<br>指示を「Excel生成」と判定、確定版編集指示が保持されているか確認<br>→ 子Cを呼び出し(渡す: RITM番号+CSP+確定版編集指示)"]:::parent
        CC2["<b>子C</b> Excel生成<br>確定版→行データJSON(見出しと完全一致)<br>→ツール⑥→返却件数と突合(検算R3)"]:::child
        O5b["<b>親</b> 子Cから件数・Excelリンク・R3結果を受領し保持<br>→ Engへ報告+「Eng確認→Mgmt経由でスレッド連携」を案内"]:::parent
        E5b["<b>Eng</b><br>Excelを確認、【案件名】を書き換え→Mgmtへ"]:::human
    end

    subgraph P6["Phase 6: 送付・回答(人間のみ)"]
        M6["<b>Mgmt</b><br>Excelリンク+構成図修正依頼をスレッドで利用者へ"]:::human
        U6["<b>利用者</b><br>回答記入・構成図修正<br>回答済みExcelをスレッドへ添付返送(ファイル名のRITM部分は変えない)"]:::human
        M6b["<b>Mgmt</b><br>返送を確認→Engへ連絡"]:::human
    end

    subgraph P7["Phase 7: 回答回収"]
        E7["<b>Eng</b><br>親へ「回答を確認して」"]:::human
        O7a["<b>親</b> Engから指示文を受領<br>指示を「回答回収」と判定<br>→ 子Cを呼び出し(渡す: RITM番号)"]:::parent
        CC3["<b>子C</b> 回答回収<br>ツール⑦→対象ファイル・全行数・md表<br>→「回答済み」「未回答」「要確認」に仕分け→検算R4"]:::child
        O7b["<b>親</b> 子Cから回答回収結果を受領し保持<br>→ Engへ原文のまま提示"]:::parent
        Q{"<b>Eng</b><br>質疑・修正依頼は解消?"}:::decision
        O7c["<b>親</b> Engから指摘を受領<br>→ 子Cを呼び出し(渡す: RITM番号+回答回収結果+Engの指摘、依頼「レビュー票を見直して」)"]:::parent
    end

    subgraph P8["Phase 8: 最終確認・クローズ(人間のみ)"]
        V["<b>Eng</b><br>判定結果・票・最終構成図を最終確認→Mgmtへ"]:::human
        MF["<b>Mgmt</b><br>利用者へ最終連携"]:::human
        CL["<b>Eng・Mgmt</b><br>スレッドをクローズ"]:::human
    end

    subgraph P9["Phase 9: ナレッジ登録"]
        E9["<b>Eng</b><br>親へ「ナレッジに登録して」"]:::human
        O9a["<b>親</b> Engから指示文を受領<br>指示を「クローズ処理」と判定<br>→ 子Bを呼び出し(渡す: RITM番号+最終判定結果、依頼「ナレッジ登録文案を作成して」)"]:::parent
        CB3["<b>子B</b> ナレッジ登録文案作成<br>技術相談ナレッジListの16項目<br>確定できない項目は「(未記入)」"]:::child
        O9b["<b>親</b> 子Bから文案を受領し「案」として保持<br>→ Engへ提示+「承認しますか」"]:::parent
        E9b{"<b>Eng</b><br>文案を確認・修正"}:::decision
        O9c["<b>親</b> Engから承認(+修正内容)を受領、承認前は実行させない(C1)<br>→ 子Bを呼び出し(渡す: 承認済み文案、依頼「登録を実行して」)"]:::parent
        CB4["<b>子B</b> ナレッジ登録<br>ツール⑧で技術相談ナレッジListへ1件登録"]:::child
        O9d["<b>親</b> 子Bから登録リンクを受領<br>→ Engへ登録完了を報告"]:::parent
    end

    A --> B --> O1a
    O1a -->|"画像あり"| CA1 --> O1b
    O1a -->|"画像なし(「構成図: Eng目視確認が必要」を付記)"| O1b
    O1b --> CB1 --> O1c --> D

    D -->|"追加確認が必要"| GH --> GM --> E2 --> O2a --> CB2 --> O1c
    D -->|"情報充足"| E3

    E3 --> O3a --> CC1 --> O3b --> E3b
    E3b -->|"修正あり"| O3c --> CC1
    E3b -->|"確定"| O3d --> E4

    E4 --> O4a --> CD1 --> O4b --> E4b --> E5
    E5 --> O5a --> CC2 --> O5b --> E5b --> M6 --> U6 --> M6b --> E7
    E7 --> O7a --> CC3 --> O7b --> Q

    Q -->|"未解消(編集指示の見直し)"| O7c --> CC1
    Q -->|"構成・前提の変更あり"| B
    Q -->|"解消・最終合意"| V --> MF --> CL --> E9

    E9 --> O9a --> CB3 --> O9b --> E9b
    E9b -->|"承認(+修正内容)"| O9c --> CB4 --> O9d

    classDef human fill:#deebf7,stroke:#7da2d6,color:#000000;
    classDef parent fill:#86bc25,stroke:#5e8a14,color:#ffffff;
    classDef child fill:#d9ead3,stroke:#86bc25,color:#000000;
    classDef decision fill:#ffe599,stroke:#c9a227,color:#000000;
    linkStyle default stroke:#5a5a5a,stroke-width:1.5px;
