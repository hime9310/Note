variable "aws_region" {
  description = "AWSリージョン"
  type        = string
}

variable "aws_account_id" {
  description = "AWSアカウントID"
  type        = string
}

variable "instance_ids" {
  description = "スケジュール対象のEC2インスタンスIDリスト"
  type        = list(string)

  validation {
    condition     = length(var.instance_ids) > 0
    error_message = "instance_ids は1つ以上のインスタンスIDを含む必要があります。"
  }
}
