承知しました。実リソース名は入れず、プレースホルダ表記（`<>` 部分を実環境の値に置換）の削除手順書としてまとめます。Venafi側の状態はすべて「AWS側で削除に進むための条件」として組み込んでいます。

---

# ALB証明書集約に伴うAWSリソース削除手順書

## 0. 前提条件（Venafi側の状態＝AWS削除作業の開始条件）

以下がすべて満たされるまで、AWS側の削除作業（フェーズ1以降）に着手しない。

| 条件 | 内容 | 確認方法 |
|---|---|---|
| C1 | 旧・個別ドメイン用のVenafiアプリケーションオブジェクト全件で自動更新が停止されていること（Processing Disabled） | Venafi管理画面で対象オブジェクトの状態確認 |
| C2 | マルチドメイン証明書がVenafiから発行され、ACMへインポート済みであること | ACM上で該当証明書が「発行済み/インポート済み」 |
| C3 | マルチドメイン証明書のSANに対象の全FQDNが漏れなく含まれ、有効期限が十分であること | 下記コマンドで確認 |
| C4 | 各サイト担当への事前確認（証明書ピンニング実装が無いこと）が完了していること | 確認記録 |
| C5 | メンテナンスウィンドウ（または低トラフィック時間帯）が確保されていること | 作業調整記録 |

```bash
# C3の確認
aws acm get-certificate --certificate-arn <新証明書ARN> --query Certificate --output text \
  | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
aws acm describe-certificate --certificate-arn <新証明書ARN> --query 'Certificate.[NotAfter]'
```

**C1が特に重要な理由**: 旧オブジェクトの自動更新が生きていると、削除作業後にVenafiが旧構成（個別証明書のSNI追加）を再Pushし、削除した状態が巻き戻される。C1はフェーズ2完了まで維持し続けること。

## 1. フェーズ1: リスナーからの削除（作業当日・メンテナンスウィンドウ内）

このフェーズで削除するのは「リスナーへの紐づけ」のみ。ACM上の証明書本体は削除しない（切り戻し手段として温存）。

**W1. 作業前バックアップの取得**

```bash
aws elbv2 describe-listener-certificates --listener-arn <リスナーARN> \
  --output json > listener_certs_backup_$(date +%Y%m%d_%H%M).json
```

このファイルは切り戻し時の復元元となるため、作業端末以外にも保管する。

**W2. デフォルト証明書をマルチドメイン証明書へ置換**

```bash
aws elbv2 modify-listener --listener-arn <リスナーARN> \
  --certificates CertificateArn=<新証明書ARN>
```

**W3. 中間確認（削除前のゲート）**

全対象FQDNに対しSNI付きで接続し、返る証明書のシリアルが新証明書と一致することを確認する（内部ALBの場合はVPC内の端末から実行）。

```bash
# 新証明書のシリアル（期待値）
aws acm get-certificate --certificate-arn <新証明書ARN> --query Certificate --output text \
  | openssl x509 -noout -serial

# 各FQDNの実測（全FQDN分繰り返し）
echo | openssl s_client -connect <ALBのDNS名>:443 -servername <対象FQDN> 2>/dev/null \
  | openssl x509 -noout -serial -enddate
```

※ この時点ではSNIリスナー証明書が残っているため、一部FQDNで旧証明書のシリアルが返っても異常ではない。**1件でも新証明書のシリアルが返ることが確認できればW4へ進んでよい**（デフォルト証明書の設定自体は成功している）。全FQDNの一致確認はW5で行う。

**W4. SNIリスナー証明書の全件削除（リスナーからの解除）**

`IsDefault` が `false` の証明書を全件（現行世代・蓄積した旧世代の区別なく）一括で削除する。

```bash
# 削除対象の一覧化
aws elbv2 describe-listener-certificates --listener-arn <リスナーARN> \
  --query 'Certificates[?IsDefault==`false`].CertificateArn' --output text

# 一括削除（上記で得たARNをすべて列挙）
aws elbv2 remove-listener-certificates --listener-arn <リスナーARN> \
  --certificates CertificateArn=<ARN-1> CertificateArn=<ARN-2> ...
```

**W5. フェーズ1の正常性確認**

1. リスナー構成の確認: 証明書がデフォルト1枚のみであること

```bash
aws elbv2 describe-listener-certificates --listener-arn <リスナーARN> \
  --query 'Certificates[].[CertificateArn,IsDefault]' --output table
```

2. 全FQDNの証明書確認: W3のopensslループを再実行し、**全FQDNで新証明書のシリアルが返る**こと
3. アプリケーション疎通: 各サイトへブラウザまたはcurlでアクセスし、証明書警告なし・HTTP応答正常であること
4. 監視確認: 対象システムの監視アラートが発報していないこと
5. 翌営業日以降: ALBアクセスログの `chosen_cert_arn` が全行新証明書のARNであり、`domain_name` に想定外の値（SANに無いホスト名への大量アクセス）が無いこと

**フェーズ1完了後もC1（Venafi自動更新の停止）を維持したまま、1〜2週間の安定稼働観察期間に入る。**

## 2. フェーズ2: ACM上の旧証明書削除（安定稼働確認後）

**開始条件（すべて必須）**:

- 観察期間中、証明書起因の障害報告・アラートがゼロであること
- ALBアクセスログで新証明書のみが提示されていることを確認済みであること
- **Venafi側で旧アプリケーションオブジェクトの削除（またはRetire）が完了し、旧証明書を再Pushする経路が恒久的に閉じられていること** ← これが完了するまでACM削除に着手しない。順序が逆になると、削除済みACM証明書への再Pushが走り新たな孤児証明書が生成される

**W6. 削除対象の特定と削除**

対象は、旧・個別ドメイン証明書の全世代（リスナー解除済みのもの、および過去にPushされたが一度も紐づかなかったもの）。1枚ずつ以下を実施する。

```bash
# 使用中でないことの確認（空配列 [] であること）
aws acm describe-certificate --certificate-arn <旧証明書ARN> --query 'Certificate.InUseBy'

# 削除
aws acm delete-certificate --certificate-arn <旧証明書ARN>
```

`InUseBy` が空でないものは他リソースに紐づいているため削除せず、紐づけ先を調査する。

**W7. フェーズ2の正常性確認**

ACM削除はデータプレーンに影響しない操作だが、念のため削除完了後にW5の項目2〜4を再実行し、配信証明書・疎通に変化がないことを確認する。あわせて、新証明書の有効期限監視が設定されていることを確認する。

## 3. 切り戻し手順

### 3-1. 切り戻しの判断基準（フェーズ1作業中〜観察期間）

次のいずれかに該当したら切り戻しを発動する: いずれかのFQDNで証明書エラー（名前不一致・検証失敗）が発生した場合、W5の確認で新証明書のシリアルが返らないFQDNが残った場合、特定のクライアント・連携システムから接続不可の報告があった場合（ピンニング実装の見落とし等）。

### 3-2. 切り戻し手順（フェーズ2着手前まで有効）

ACM上に旧証明書がすべて残っているため、以下で作業前の状態に完全復元できる。所要は数分。

```bash
# 1. デフォルト証明書を旧デフォルトへ戻す
#    （旧デフォルトのARNはW1のバックアップJSON内 IsDefault:true のエントリ）
aws elbv2 modify-listener --listener-arn <リスナーARN> \
  --certificates CertificateArn=<旧デフォルト証明書ARN>

# 2. SNIリスナー証明書を再追加
#    （バックアップJSON内 IsDefault:false の全ARNを列挙）
aws elbv2 add-listener-certificates --listener-arn <リスナーARN> \
  --certificates CertificateArn=<ARN-1> CertificateArn=<ARN-2> ...

# 3. 復元確認: 全FQDNで旧証明書のシリアルが返ること＋疎通正常
```

切り戻し後は、C1の停止状態を維持したまま原因調査を行う（自動更新を再開すると旧構成のまま世代蓄積が再発するため）。

### 3-3. フェーズ2実施後の復旧（切り戻し不可領域）

**ACM削除後は3-2の切り戻しは実行できない**（削除した証明書は復元不能）。この段階で問題が発覚した場合の復旧経路は、Venafiから該当ドメインの証明書を再発行し、ACMへインポートの上でリスナーに追加する、となり数時間規模を要する。だからこそフェーズ2の開始条件（観察期間の完了）を厳守する。

### 3-4. ロールバックポイント一覧

| タイミング | 切り戻し可否 | 方法 | 所要目安 |
|---|---|---|---|
| W2〜W4作業中 | 可 | 3-2の手順 | 数分 |
| フェーズ1完了後〜観察期間中 | 可 | 3-2の手順 | 数分 |
| フェーズ2（ACM削除）以降 | 不可（復元不能） | Venafiから再発行・再Push | 数時間〜 |

