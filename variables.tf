variable "aws_region" {
  description = "AWSリージョン"
  type        = string
}

variable "aws_account_id" {
  description = "AWSアカウントID"
  type        = string
}

variable "linux_instance_ids" {
  description = "スケジュール対象のLinux EC2インスタンスIDリスト（平日+土日）"
  type        = list(string)

  validation {
    condition     = length(var.linux_instance_ids) > 0
    error_message = "linux_instance_ids は1つ以上のインスタンスIDを含む必要があります。"
  }
}

variable "windows_instance_ids" {
  description = "スケジュール対象のWindows EC2インスタンスIDリスト（平日のみ）"
  type        = list(string)

  validation {
    condition     = length(var.windows_instance_ids) > 0
    error_message = "windows_instance_ids は1つ以上のインスタンスIDを含む必要があります。"
  }
}
