「ツールがどうやって Microsoft にサインインするか」の1つの話の部品なので、先に全体像だけ。

今回のツールが Teams や SharePoint を読むには、Microsoft に「このツールは何者か」を登録する必要があります。それが Entra ID の「アプリ登録」です。登録するとアプリの ID がもらえて、実際に動くときは「利用者がサインインする → Microsoft から『この人の代わりに読んでよい』という許可証(トークン)をもらう → その許可証を付けて Graph API を呼ぶ」という流れになります。3つの用語はこの流れの中の「どうやってサインインするか」「どんな種類のアプリとして登録するか」「アプリ自身の鍵を持つか」です。

MSAL ライブラリは、Microsoft Authentication Library の略で、Microsoft が公式に配っている「サインインと許可証の取得をやってくれるプログラム部品」です。自分でサインイン画面や許可証のやり取りを作ると危ないし審査も通りにくいので、Microsoft 製の部品をそのまま使います、という宣言です。社内 KB に「MSAL を使うアプリはトークンの有効化申請が不要」とあったので、「公式の正しいやり方でサインインします」と伝えるために書きました。問い合わせ文では「Microsoft 公式のサインイン方式を使う」と読み替えてもらって問題ありません。

パブリッククライアント(デスクトップ)は、アプリ登録のときに選ぶ「アプリの種類」です。アプリは大きく2種類に分かれます。1つはサーバーの上で動く Web アプリで、秘密の鍵を安全に金庫に入れておけるタイプ。もう1つは利用者の PC やスマホの上で動くアプリで、利用者の手元にあるので秘密を安全に隠せない前提のタイプ。後者が「パブリッククライアント」で、Outlook や Teams のデスクトップアプリ、Azure CLI などが同じ種類です。今回のツールは各 社用 PC で動くので、こちらに当たります。「パブリック」は「社外に公開する」という意味ではなく、「秘密を持たない側のアプリ」という意味なので、そこは誤解されないように書き分けました(問い合わせ文では「外部公開なし」も明記しています)。

クライアントシークレットは「アプリ用のパスワード」です。Web アプリ(サーバー)はこれを持っていて、「私は本物のアプリです」と Microsoft に証明します。パブリッククライアントはこのパスワードを持たず、「利用者本人がサインインした」ことだけでアクセスします。シークレットが無いと、漏えいする物がそもそも無い、KB の Q8 にあった期限切れアラートや更新作業が要らない、各 社用 PC にパスワードを配らなくてよい、という利点があるので「なしを希望」と書きました。ただ、社内の登録ツールでパブリッククライアントが選べない可能性もあるので、「不可なら Web+シークレットでも可」を添えています。その場合はシークレットを安全に保管する場所と期限管理が必要になる、というだけで、やりたいこと自体は変わりません。

一文でまとめると、「社用 PC 上で動くアプリ(パブリッククライアント)が、Microsoft 公式の部品(MSAL)で利用者本人をサインインさせ、アプリ用パスワード(シークレット)は持たずに、本人が見られる範囲だけを読む」という構成です。

問い合わせ文は、グレースさんが向こうから聞き返されたときに自分の言葉で答えられる表現のほうがよいので、想定構成の3行を「認証: 利用者本人が普段どおり Microsoft にサインインする方式(Microsoft 公式ライブラリ MSAL を使用)」「アプリ種別: 社用 PC 上で動くデスクトップアプリ(パブリッククライアント)」「アプリ用のパスワード(クライアントシークレット)は持たない構成を希望。難しければシークレットありでも可」のように、かっこで平易な言い換えを付けた形に直すこともできます。そのほうがよければ日本語・英語の両方を直します。

ーーーーー
Global Service Desk ご担当者様

【氏名】です。
社内の PoC ツールから Microsoft Graph API を使って Teams と SharePoint を「読み取りのみ」で利用したいと考えています。そのために必要な Entra ID アプリの登録と API 権限の付与が社内ルール上可能か、可能な場合にどのような申請・手順が必要かを確認したくご連絡しました。認証・API周りは不慣れなため、用語や前提に誤りがあればご指摘ください。

■ やりたいこと
- アーキテクチャレビュー業務(利用者から受領した構成図の確認)を AI で効率化する PoC を進めています。
- 社用社用PC上で動くツールから、Teams の特定チャネルのスレッド本文と、SharePoint の特定フォルダのファイルを「読み取りのみ」で取得したいです。
- そのために、Microsoft Graph API を利用する Entra ID アプリの登録と API 権限の付与が必要と理解しています。

■ 想定構成
- 利用者: JP (社内ユーザーのみ。外部公開なし)
- 動作場所: 各 社用社用PC上(サーバーなし。クラウドへのデータ保存なし)
- 認証: 利用者本人が普段どおり Microsoft にサインインし、本人が見られる範囲だけにアクセスする方式(委任権限/Delegated。Microsoft 公式ライブラリ MSAL を使用)。ユーザー不在でアクセスするアプリケーション権限は使いません
- アプリ種別: 社用 PC 上で動くデスクトップアプリ(パブリッククライアント)
- アプリ用のパスワード(クライアントシークレット)は持たない構成を希望します。難しい場合はシークレットありの構成でも可です
- 操作: Graph API の GET(読み取り)のみ。Teams への投稿、SharePoint への書き込みは行いません
- 対象: 特定のチーム/チャネル1つ、特定の SharePoint サイト1つに限定。いずれも日本テナント側(jpdeloitte.sharepoint.com)です

■ 必要と考えている API 権限(すべて委任・読み取り)
- ChannelMessage.Read.All(チャネルのメッセージと返信の読み取り)
- Sites.Read.All または Files.Read.All(SharePoint のファイル読み取り)
- User.Read / offline_access(既定で承認済みと理解しています)
- Team.ReadBasic.All / Channel.ReadBasic.All(チーム名・チャネル名の取得)

■ 確認したいこと
1. 可否: 上記の構成・権限で Entra ID アプリの登録と権限付与は可能でしょうか。
   (可 / 条件付きで可 / 不可。条件や不可の理由があればその内容)
2. 権限の承認: 上記の権限のうち、追加の承認(セキュリティ部門の審査など)が必要なものはどれでしょうか。また、その申請先と申請方法を教えてください。
   (権限ごとに 承認不要 / 要承認、要承認の場合の申請先・方法)
3. 手順: アプリ登録から利用開始までに必要な申請と手順を、順番と所要期間の目安とともに教えてください。登録の前に必要な審査や登録があれば、それも含めてお願いします。
   (ステップの一覧と、各ステップのおおよその期間)
4. 登録の形式: Application Registration Tool で、デスクトップアプリ(パブリッククライアント、シークレットなし)として登録できますか。できない場合、推奨される登録形式を教えてください。
   (可 / 不可。不可の場合の推奨形式)
5. 利用条件: Teams のメッセージ本文を読む権限(ChannelMessage.Read.All)について、対象チャネルの限定・ログの取得・関係者への周知など、守るべき条件はありますか。
   (条件の有無と内容)
6. 申請者: 申請は担当 Eng 個人のアカウントで行ってよいでしょうか。
   (可 / 不可。不可の場合は誰が申請すべきか)

ご多忙のところ恐れ入りますが、ご確認のほどよろしくお願いいたします。

ーーーー
Dear Global Service Desk team,

I am [Name], .
We would like to use the Microsoft Graph API from an internal PoC tool to access Teams and SharePoint on a read-only basis. I am contacting you to confirm whether the required Entra ID application registration and API permission grants are permitted under our internal rules and, if so, which requests and steps are needed. I am not familiar with authentication / API topics, so please correct me if any terms or assumptions are wrong.

[What we want to do]
- We are running a PoC that uses AI to streamline our architecture review process (reviewing architecture diagrams received from internal users).
- A tool running on engineers' corporate laptops needs to read (read-only) thread messages from one specific Teams channel and files from one specific SharePoint folder.
- We understand this requires registering an Entra ID application and granting Microsoft Graph API permissions.

[Planned setup]
- Users: a few engineers in JP CMS (internal users only, no external access)
- Runs on: each engineer's corporate laptop (no server, no data stored in the cloud)
- Authentication: the user signs in to Microsoft as usual and the tool accesses only what that user can already see (delegated permissions, using the official Microsoft library MSAL). No application permissions (no access without a signed-in user)
- App type: desktop application running on the engineer's PC (public client)
- We would prefer a configuration without an application password (client secret). If that is not possible, a configuration with a client secret is acceptable
- Operations: Microsoft Graph GET (read) calls only. No posting to Teams, no writing to SharePoint
- Scope: limited to one team/channel and one SharePoint site, both in the Japan tenant (jpdeloitte.sharepoint.com)

[Permissions we believe are required (all delegated, read-only)]
- ChannelMessage.Read.All (read channel messages and replies)
- Sites.Read.All or Files.Read.All (read SharePoint files)
- User.Read / offline_access (we understand these are pre-approved)
- Team.ReadBasic.All / Channel.ReadBasic.All (team and channel names)

[Questions]
1. Feasibility: Can an Entra ID application be registered and granted the permissions above with this setup?
   (Yes / Yes with conditions / No. If there are conditions or reasons, please describe them.)
2. Permission approval: Which of the permissions above require additional approval (e.g., a security review)? Where and how should such approval be requested?
   (For each permission: no approval needed / approval needed, and where and how to request it.)
3. Procedure: Which requests and steps are needed from application registration to go-live, in what order, and with what approximate lead time? Please include any reviews or registrations required before the application can be registered.
   (A list of steps with the approximate duration of each.)
4. Registration type: Can the application be registered in the Application Registration Tool as a desktop application (public client, no client secret)? If not, which registration type is recommended?
   (Yes / No. If No, the recommended type.)
5. Conditions of use: For the permission to read Teams message content (ChannelMessage.Read.All), are there conditions we must follow, such as limiting the target channels, logging, or notifying stakeholders?
   (Whether there are conditions, and what they are.)
6. Requestor: Can the request be submitted under an individual engineer's account?
   (Yes / No. If No, who should submit it.)

Thank you very much for your support.

[Name / Department / Contact]
