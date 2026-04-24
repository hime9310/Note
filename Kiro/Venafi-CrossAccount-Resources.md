# Venafi クロスアカウント構成 リソース一覧

## 構成概要

```
Venafi（オンプレ）
  ↓ アクセスキー＋シークレット（1セット）
踏み台アカウント（123456789123）
  IAMユーザー: venafi-automation-user
  ↓ AssumeRole（External ID: BastionExternalID1）
  ├── 子アカウントA: venafi-cross-role
  ├── 子アカウントB: venafi-cross-role
  └── 子アカウントC: venafi-cross-role
```

---

## 1. 踏み台アカウント（AccountID: 123456789123）

### 1-1. IAMユーザー

| 項目 | 内容 |
|------|------|
| リソース名 | `venafi-automation-user` |
| 種別 | IAMユーザー |
| 目的 | VenafiがAWSへ接続するための入り口 |

---

### 1-2. アクセスキー

| 項目 | 内容 |
|------|------|
| 対象ユーザー | `venafi-automation-user` |
| 目的 | VenafiのCredential設定に登録するキー |
| 備考 | 発行後、VenafiのAccess Key / Secret Key欄に登録 |

---

### 1-3. IAMポリシー（AssumeRole用）

| 項目 | 内容 |
|------|------|
| リソース名 | `venafi-assumerole-policy` |
| 種別 | IAM管理ポリシー |
| 目的 | 各子アカウントのロールへのAssumeRoleを許可 |

**ポリシー内容：**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": [
        "arn:aws:iam::子アカウントA_ID:role/venafi-cross-role",
        "arn:aws:iam::子アカウントB_ID:role/venafi-cross-role",
        "arn:aws:iam::子アカウントC_ID:role/venafi-cross-role"
      ]
    }
  ]
}
```

---

### 1-4. ポリシーのアタッチ

| 対象ユーザー | アタッチするポリシー |
|-------------|-------------------|
| `venafi-automation-user` | `venafi-assumerole-policy` |

---

## 2. 子アカウント側（各アカウント共通）

### 2-1. IAMロール

| 項目 | 内容 |
|------|------|
| リソース名 | `venafi-cross-role` |
| 種別 | IAMロール |
| 目的 | 踏み台アカウントからのAssumeRoleを受け入れ、Venafiの操作を許可する |

---

### 2-2. 信頼ポリシー（Trust Policy）

**ポリシー内容：**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789123:user/venafi-automation-user"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "BastionExternalID1"
        }
      }
    }
  ]
}
```

---

### 2-3. 許可ポリシー（Permission Policy）

`venafi-cross-role` にアタッチするポリシー：

| # | ポリシー名 | 内容 | 備考 |
|---|-----------|------|------|
| 1 | `venafi-assumerole-policy` | 踏み台からのAssumeRole許可 | 今回新規作成 |
| 2 | Venafi操作用ポリシー | ACM / IAM / ALB / CloudFront等の操作権限 | ※ 既存流用 |

> ※ Venafi操作用ポリシーは現在各子アカウントのIAMユーザーにアタッチしている既存ポリシーをそのまま流用

---

## 3. Venafiへの登録内容

| 項目 | 値 |
|------|-----|
| Source | Local |
| Access Key | 踏み台アカウント `venafi-automation-user` のアクセスキー |
| Secret Key | 踏み台アカウント `venafi-automation-user` のシークレットキー |
| Role To Assume | `arn:aws:iam::子アカウントID:role/venafi-cross-role` |
| External ID | `BastionExternalID1` |

---

## 4. 作業順序

```
Step 1: 踏み台アカウント（123456789123）
  → IAMユーザー（venafi-automation-user）作成
  → アクセスキー発行
  → venafi-assumerole-policyを作成してアタッチ

Step 2: 各子アカウント
  → IAMロール（venafi-cross-role）作成
  → 信頼ポリシーに踏み台ユーザーARN＋ExternalIDを設定
  → 許可ポリシー（既存流用＋新規）をアタッチ

Step 3: Venafi
  → Amazon Credentialに踏み台のキーを登録
  → Role To AssumeにロールARNを登録
  → External IDにBastionExternalID1を登録
  → 動作確認・検証
```
