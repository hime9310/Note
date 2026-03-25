# tfstateをローカル管理
# terraform.tfstate はこのディレクトリに生成される
# Gitにはコミットしないこと（.gitignoreに追記済み）
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
