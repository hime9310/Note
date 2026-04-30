# Kiro MCP サーバー セットアップガイド

Terraform MCP Server と draw.io MCP Server の導入手順をまとめたドキュメントです。

---

## 前提条件

| ツール | 確認コマンド | 用途 |
|---|---|---|
| Node.js（v18以上） | `node -v` | draw.io MCP の実行に必要 |
| npm / npx | `npx -v` | draw.io MCP のインストールに必要 |

---

## 1. Terraform MCP Server

### 1-1. バイナリのダウンロード

以下のURLから最新バージョンのバイナリを取得します。

```
https://releases.hashicorp.com/terraform-mcp-server/
```

Windows（64bit）の場合：

```
terraform-mcp-server_0.5.1_windows_amd64.zip
```

解凍後、バイナリを任意のパスに配置します。

```
C:\tools\terraform-mcp-server\terraform-mcp-server.exe
```

---

### 1-2. 動作確認

コマンドプロンプトで以下を実行し、エラーなく起動すれば問題ありません。

```powershell
C:\tools\terraform-mcp-server\terraform-mcp-server.exe stdio
```

`Ctrl+C` で終了します。

---

## 2. draw.io MCP Server

### 概要

draw.io 公式（jgraph）が提供する MCP サーバーです。
Kiro から draw.io の構成図を生成・編集できるようになります。

- **npm パッケージ名**：`@drawio/mcp`
- **インストール不要**：npx 経由で自動取得

---

## 3. Kiro への MCP 設定

### 設定ファイルの場所

| スコープ | パス | 用途 |
|---|---|---|
| ワークスペース共通 | `.kiro/settings/mcp.json` | チーム全員に適用（推奨） |
| 個人のみ | `~/.kiro/settings/mcp.json` | 自分だけに適用 |

> 両方ある場合はワークスペース設定が優先されます。

---

### 3-1. mcp.json の設定内容

`.kiro/settings/mcp.json` に以下を記載します。

```json
{
  "mcpServers": {
    "terraform": {
      "command": "C:\\tools\\terraform-mcp-server\\terraform-mcp-server.exe",
      "args": ["stdio"],
      "disabled": false
    },
    "drawio": {
      "command": "npx",
      "args": ["@drawio/mcp"],
      "disabled": false
    }
  }
}
```

> **注意**
> - `terraform` のパスは実際に配置した場所に合わせて変更してください
> - バックスラッシュは `\\` と記載してください（JSON のエスケープ）
> - `TFE_TOKEN` は検証フェーズでは**不要**です（公開レジストリ参照のみ）

---

### 3-2. サイドパネルでサーバーを有効化

設定ファイル保存後、以下の手順でサーバーを有効化します。

1. 左側の **Kiro アイコン**をクリックしてサイドパネルを開く
2. **「MCP Servers」セクション**を確認
3. 追加したサーバー（`terraform`、`drawio`）が表示されていることを確認
4. サーバーが無効状態の場合、**「Enable」ボタン**をクリックして有効化
5. サーバーの状態が **running** になるまで待つ

> **補足**：`mcp.json` を変更した場合、Kiro の再起動なしにサイドパネルから反映できます。
> サーバーが表示されない場合は Kiro を再起動してください。

---

### 3-3. 動作確認

**チャットの `/mcp` コマンドはKiroでは使用できません**（VS Code Copilot Chat 専用のコマンドです）。

サイドパネルの「MCP Servers」セクションで各サーバーが **running** 状態であれば接続成功です。

チャットで実際に動作確認する場合は以下のように入力します。

```
draw.io の MCP ツールを使って簡単な図を作成してください
```

ツールが正常に呼び出されれば接続成功です。エラーが返る場合は設定を見直してください。

---

## 4. 各 MCP Server でできること

### Terraform MCP Server

| ツール | 内容 |
|---|---|
| `search_providers` | プロバイダードキュメントを検索 |
| `get_provider_details` | プロバイダーの詳細情報を取得 |
| `search_modules` | Terraform Registry のモジュールを検索 |
| `get_module_details` | モジュールの入出力・使い方を取得 |

> Token なしで上記すべて利用可能です。

### draw.io MCP Server

| ツール | 内容 |
|---|---|
| `open_drawio_xml` | XML形式で構成図を生成・draw.ioで開く |
| `open_drawio_csv` | CSVデータから図を生成 |
| `open_drawio_mermaid` | Mermaid記法から図を生成 |

---

## 5. バージョン更新時の手順

### Terraform MCP Server

```
1. https://releases.hashicorp.com/terraform-mcp-server/ で最新バージョンを確認
2. 新バイナリをダウンロード・解凍
3. 既存バイナリを上書き（パスは同じままでOK）
4. Kiro を再起動（mcp.json の変更不要）
```

### draw.io MCP Server

npx 経由のため、**自動的に最新版が使用されます**。手動更新は不要です。

---

## 6. セキュリティ注意事項

- `mcp.json` に API Token を直書きしないこと
- Token が必要になった場合は環境変数で渡すこと

```json
"env": {
  "TFE_TOKEN": "${TFE_TOKEN}"
}
```

- `mcp.json` を Git にコミットする場合は Token が含まれていないことを確認すること
