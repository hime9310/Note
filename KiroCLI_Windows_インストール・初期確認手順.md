# Kiro CLI（Windows）インストール・初期確認手順

> **対象:** Kiro IDEをメインに利用し、不具合発生時の切り分け・診断にKiro CLIを使用するチーム  
> **対象OS:** Windows 11  
> **使用シェル:** PowerShell（Command Promptでは実行しない）  
> **最終確認日:** 2026年7月24日

## 1. 本書の目的

本書では、Windows 11へKiro CLIをインストールし、次の項目を確認するまでの手順を説明します。
 　
- `kiro-cli`をPowerShellから起動できる
- Kiroへサインインできる
- 認証状態を確認できる
- CLIの基本診断を実行できる
- Kiroサービスとの最小限の疎通を確認できる

チームの通常業務ではKiro IDEを使用し、CLIは主に次の切り分けに利用します。

- Kiroサービスや認証に共通する問題か
- IDE固有の問題か
- 端末のネットワーク、プロキシ、PATH、CLI設定に問題があるか

> [!IMPORTANT]
> `kiro-cli doctor`や`kiro-cli diagnostic`はCLIの診断機能です。CLIが正常でも、Kiro IDEが正常であるとは限りません。IDE固有の問題は、IDEのログやOutputパネルも併せて確認してください。

## 2. 前提条件

- Windows 11
- Windows TerminalまたはPowerShellを利用できること
- インターネットへ接続できること
- GitHub、Google、AWS Builder ID、AWS IAM Identity Center、または組織指定のIdPでサインインできること
- 組織管理端末では、ソフトウェア導入・PowerShell・プロキシ・ファイアウォールに関する社内ルールを確認済みであること

公式ドキュメントには、Windows版CLIのCPUアーキテクチャ、必要なPowerShellのバージョン、ディスク容量、管理者権限の要否に関する明示的な記載はありません。通常のPowerShellで開始し、組織のポリシーに従ってください。

## 3. インストール

### 3.1 PowerShellを開く

Windows Terminalを起動し、**PowerShell**タブを開きます。まず通常のPowerShellで開始してください。公式ドキュメントには管理者権限の要否が明記されていないため、権限を求められた場合や組織管理端末では社内ルールに従います。

現在のシェルを確認する場合は、次を実行します。

```powershell
$PSVersionTable.PSVersion
```

### 3.2 公式インストーラーを実行する

```powershell
irm 'https://cli.kiro.dev/install.ps1' | iex
```

このコマンドは、公式URLからPowerShellインストールスクリプトを取得して実行します。組織のセキュリティ方針により外部スクリプトの直接実行が禁止されている場合は、実行せず管理者へ確認してください。

### 3.3 バージョンとPATHを確認する

インストール後、新しいPowerShellを開いて次を実行します。

```powershell
kiro-cli --version
```

詳細なバージョン情報を確認する場合は、次を実行します。

```powershell
kiro-cli version
```

実行ファイルがPATHから解決できることも確認できます。

```powershell
Get-Command kiro-cli
```

バージョン情報とコマンドの場所が表示されれば、インストールとPATHの基本確認は完了です。

> [!NOTE]
> 公式ドキュメントには、Windowsでの具体的なインストール先や手動で追加するPATH値は明記されていません。`kiro-cli`が認識されない場合は、まずPowerShellを開き直し、その後「7. トラブルシューティング」を確認してください。

## 4. 初回サインイン

### 4.1 ログインする

```powershell
kiro-cli login
```

1. ターミナルに表示される案内に従います。
2. Enterキーを押して既定ブラウザを開きます。
3. チームで指定された認証方式を選択してサインインします。
4. 認証完了後、PowerShellへ戻ります。

ブラウザが自動で開かない場合は、デバイスフローを試します。

```powershell
kiro-cli login --use-device-flow
```

> [!NOTE]
> 外部IdP（Microsoft Entra IDやOktaなど）はデバイスフローに対応していません。組織指定の認証方法を使用してください。

### 4.2 認証状態を確認する

```powershell
kiro-cli whoami
```

利用者、認証方式、セッション状態が表示されれば認証確認は完了です。認証をやり直す場合は、次の順に実行します。

```powershell
kiro-cli logout
kiro-cli login
```

## 5. 初期診断と疎通確認

### 5.1 基本診断を実行する

```powershell
kiro-cli doctor
```

`doctor`は一般的な問題を診断し、可能な項目は修正します。修正を行わずに全テストを実行したい場合は、次を使用します。

```powershell
kiro-cli doctor --all
```

より厳密に、警告もエラーとして扱う場合は次を使用します。

```powershell
kiro-cli doctor --strict
```

### 5.2 診断情報を取得する

CLIを通常起動していない状態でも実行できる限定診断です。

```powershell
kiro-cli diagnostic --force
```

診断結果にはCLIのパスやPATHなどの環境情報が含まれます。社外・他チームへ共有する前に、ユーザー名、パス、設定値などの機密情報が含まれていないか確認してください。

### 5.3 最小限の疎通確認を行う

作業中のリポジトリへの影響を避けるため、一時ディレクトリへ移動して非対話で確認します。

```powershell
$smokeTestDir = Join-Path $env:TEMP 'kiro-cli-smoke-test'
New-Item -ItemType Directory -Force $smokeTestDir | Out-Null
Set-Location $smokeTestDir
kiro-cli chat --no-interactive "OKとだけ返答してください"
```

応答が返れば、CLIの起動、認証、ネットワーク通信、モデル呼び出しまでの基本疎通を確認できています。

> [!CAUTION]
> 初期確認では`--trust-all-tools`を付けないでください。CLIにはファイルの読み書きやコマンド実行を行う機能があります。トラブルシューティング時も、対象リポジトリで実行する前に現在のディレクトリとGit差分を確認してください。

## 6. 初期確認チェックリスト

| 確認項目 | コマンド | 合格条件 |
|---|---|---|
| CLI起動・バージョン | `kiro-cli --version` | バージョンが表示される |
| PATH解決 | `Get-Command kiro-cli` | コマンドの場所が表示される |
| 認証 | `kiro-cli whoami` | 利用者と認証状態が表示される |
| 基本診断 | `kiro-cli doctor` | 未解決の重大エラーがない |
| 診断情報 | `kiro-cli diagnostic --force` | 診断結果が出力される |
| サービス疎通 | `kiro-cli chat --no-interactive "OKとだけ返答してください"` | 応答が返る |

すべて合格すれば、インストールから初期確認までは完了です。

## 7. トラブルシューティング

### 7.1 `kiro-cli`が認識されない

症状例：

```text
kiro-cli : 用語 'kiro-cli' は認識されません...
```

次の順に確認します。

1. PowerShellをすべて閉じ、新しいPowerShellを開く。
2. `Get-Command kiro-cli`を実行する。
3. 公式インストールコマンドを再実行する。
4. インストール時に表示されたエラーを確認する。
5. 組織のセキュリティ製品がインストールや実行を遮断していないか管理者へ確認する。

手動で追加すべきPATH値は公式ドキュメントに明記されていないため、推測でPATHを変更しないでください。

### 7.2 PowerShellスクリプトの実行が拒否される

現在の実行ポリシーを確認します。

```powershell
Get-ExecutionPolicy -List
```

公式トラブルシューティングでは、PowerShell 7以降でユーザー単位の実行ポリシーを変更する例として次が案内されています。

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

> [!WARNING]
> 実行ポリシーはセキュリティ設定です。組織管理端末では独断で変更せず、社内ルールに従って管理者へ確認してください。グループポリシーで強制されている場合、ユーザー側の変更は適用されないことがあります。

### 7.3 ログインできない・ブラウザが開かない

```powershell
kiro-cli logout
kiro-cli login
```

ブラウザが開かない場合：

```powershell
kiro-cli login --use-device-flow
```

併せて次を確認します。

- 既定ブラウザが起動できるか
- 組織指定の認証方式を選択しているか
- ブラウザ側のプロキシやファイアウォールで認証通信が遮断されていないか
- 端末の日時が正しいか

### 7.4 プロキシ環境で通信できない

Kiro CLIは`HTTP_PROXY`、`HTTPS_PROXY`、`NO_PROXY`環境変数を参照します。設定例は次のとおりです。実際の値は社内ネットワーク管理者から指定されたものへ置き換えてください。

```powershell
$env:HTTP_PROXY = 'http://proxy.example.com:8080'
$env:HTTPS_PROXY = 'http://proxy.example.com:8080'
$env:NO_PROXY = 'localhost,127.0.0.1'
```

この設定は現在のPowerShellセッションにのみ適用されます。認証時のブラウザ通信はOS・ブラウザ側のネットワーク設定も使用するため、CLI側だけでなくブラウザ側も確認してください。

必要な接続先は公式の[Firewall and network requirements](https://kiro.dev/docs/privacy-and-security/firewalls/)を参照してください。

### 7.5 詳細ログを取得する

コマンドの詳細度を上げて診断します。

```powershell
kiro-cli -vvv doctor
```

Windowsでの既定ログファイル：

```text
%TEMP%\kiro-log\logs\kiro-chat.log
```

PowerShellからログを開く例：

```powershell
notepad (Join-Path $env:TEMP 'kiro-log\logs\kiro-chat.log')
```

一時的にログ出力先を変更する例：

```powershell
$env:KIRO_CHAT_LOG_FILE = 'C:\temp\kiro-cli-debug.log'
kiro-cli chat
```

> [!WARNING]
> ログにはファイルパス、コード断片、コマンド出力、ユーザー情報などが含まれる可能性があります。チケットやチャットへ添付する前に内容を確認し、秘密情報・個人情報・社内情報をマスキングしてください。

### 7.6 Kiro IDE障害時の切り分け

次の順で確認すると、問題の範囲を整理できます。

1. `kiro-cli --version`が成功するか確認する。
2. `kiro-cli whoami`で認証状態を確認する。
3. `kiro-cli doctor --all`を実行する。
4. 一時ディレクトリで非対話の疎通確認を行う。
5. IDEとCLIの結果を次の表で分類する。

| IDE | CLI | 主な切り分け先 |
|---|---|---|
| NG | OK | IDE固有の設定、拡張機能、キャッシュ、更新状態、IDEログ |
| NG | NG | 認証、Kiroサービス、ネットワーク、プロキシ、端末共通設定 |
| OK | NG | CLIのPATH、CLI設定、CLIバージョン、CLIログ |
| OK | OK | 一時的な問題、対象ワークスペース固有の設定・権限・ファイル |

CLIはIDEの完全な診断代替ではありません。IDE固有の調査では、次も確認してください。

- Kiro IDEのOutputパネル
- Developer ToolsのConsole
- Command Paletteの`Kiro: Check for Updates`
- ターミナル連携の問題では`Kiro: Enable Shell Integration`

CLIを明示的に起動する場合は`kiro`ではなく`kiro-cli`を使用します。Command Routerが導入されている環境では、`kiro`がIDEまたはCLIへ振り分けられる可能性があるためです。

### 7.7 解決しない場合

診断情報とログを確認したうえで、CLIから問題を報告できます。

```powershell
kiro-cli issue
```

報告時は最低限、次の情報を整理します。

- 発生日時と再現手順
- `kiro-cli version`の結果
- Windowsのバージョン
- `kiro-cli doctor --all`の結果
- IDEでも同じ問題が発生するか
- プロキシ・VPNの利用有無
- 機密情報を除去したログまたはエラーメッセージ

## 8. 更新とアンインストール

### 8.1 更新

Kiro CLIはバックグラウンドで更新を取得し、アプリ終了時にインストールします。手動更新は次のとおりです。

```powershell
kiro-cli update
```

確認なしで更新する場合：

```powershell
kiro-cli update --non-interactive
```

更新後はバージョンと診断を再確認します。

```powershell
kiro-cli --version
kiro-cli doctor --all
```

### 8.2 アンインストール

```powershell
kiro-cli uninstall
```

または、Windowsの**設定 > アプリ**からKiro CLIを削除します。

公式ドキュメントには、アンインストール時にユーザー設定や保存済みセッションがすべて削除されるかは明記されていません。端末廃棄やユーザー変更の際は、必要に応じて先にログアウトしてください。

```powershell
kiro-cli logout
```

## 9. チーム運用上の推奨事項

- 通常の開発はKiro IDEを使用し、CLIは障害切り分け・診断用とする。
- 初期導入時に「6. 初期確認チェックリスト」の結果を記録する。
- トラブル時は`kiro-cli`を明示的に使用し、Command Router経由の`kiro`と混同しない。
- 初期確認や診断では`--trust-all-tools`を使用しない。
- 対象リポジトリでCLIを起動する前に、現在のディレクトリとGit差分を確認する。
- ログや診断結果は、機密情報をマスキングしてから共有する。
- CLIの更新前後で`kiro-cli version`を記録し、チーム内でバージョン差を把握する。
- CLI 3.0 Early Accessを試す場合は通常版と結果を混同せず、検証用途に限定する。

## 10. 公式ドキュメント

- [Kiro CLI installation](https://kiro.dev/docs/cli/installation/)
- [Kiro CLI authentication](https://kiro.dev/docs/cli/authentication/)
- [Kiro CLI quick start](https://kiro.dev/docs/cli/quick-start/)
- [Kiro CLI command reference](https://kiro.dev/docs/cli/reference/cli-commands/)
- [Kiro troubleshooting](https://kiro.dev/docs/troubleshooting/)
- [Firewall and network requirements](https://kiro.dev/docs/privacy-and-security/firewalls/)
- [Kiro IDE installation](https://kiro.dev/docs/getting-started/installation/)

> 本書は上記の公式ドキュメントを基に要約・再構成しています。Kiro CLIは更新されるため、実行結果や画面が異なる場合は最新の公式ドキュメントを確認してください。