# 同期先をGoogleに変更
PS> w32tm /config /manualpeerlist:"time.google.com" /syncfromflags:manual /reliable:YES /update
PS> w32tm /resync

# 確認
PS> w32tm /query /status
PS> w32tm /query /source


