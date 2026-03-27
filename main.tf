# =============================================================================
# locals: スケジュール定義
# =============================================================================
locals {
  all_instance_ids = concat(var.linux_instance_ids, var.windows_instance_ids)

  schedules = {
    weekday_start = {
      name         = "ec2-weekday-start"
      description  = "平日朝9時にEC2インスタンスを起動"
      cron         = "cron(0 9 ? * MON-FRI *)"
      action       = "startInstances"
      instance_ids = local.all_instance_ids
    }
    weekday_stop = {
      name         = "ec2-weekday-stop"
      description  = "平日午後6時にEC2インスタンスを停止"
      cron         = "cron(0 18 ? * MON-FRI *)"
      action       = "stopInstances"
      instance_ids = local.all_instance_ids
    }
    saturday_start = {
      name         = "ec2-saturday-start"
      description  = "土曜日0時にLinuxインスタンスを起動"
      cron         = "cron(0 0 ? * SAT *)"
      action       = "startInstances"
      instance_ids = var.linux_instance_ids
    }
    sunday_stop = {
      name         = "ec2-sunday-stop"
      description  = "日曜日19時にLinuxインスタンスを停止"
      cron         = "cron(0 19 ? * SUN *)"
      action       = "stopInstances"
      instance_ids = var.linux_instance_ids
    }
  }
}

# =============================================================================
# IAM: EventBridge Scheduler用 Role & Policy
# =============================================================================
data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler_ec2" {
  name               = "eventbridge-scheduler-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json
}

data "aws_iam_policy_document" "scheduler_ec2" {
  statement {
    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances",
    ]
    resources = [
      for id in local.all_instance_ids :
      "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:instance/${id}"
    ]
  }
}

resource "aws_iam_role_policy" "scheduler_ec2" {
  name   = "eventbridge-scheduler-ec2-policy"
  role   = aws_iam_role.scheduler_ec2.id
  policy = data.aws_iam_policy_document.scheduler_ec2.json
}

# =============================================================================
# EventBridge Scheduler: Schedule Group & Schedules
# =============================================================================
resource "aws_scheduler_schedule_group" "ec2" {
  name = "ec2-instance-schedules"
}

resource "aws_scheduler_schedule" "ec2" {
  for_each = local.schedules

  name        = each.value.name
  description = each.value.description
  group_name  = aws_scheduler_schedule_group.ec2.name

  schedule_expression          = each.value.cron
  schedule_expression_timezone = "Asia/Tokyo"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:${each.value.action}"
    role_arn = aws_iam_role.scheduler_ec2.arn

    input = jsonencode({
      InstanceIds = each.value.instance_ids
    })

    retry_policy {
      maximum_event_age_in_seconds = 86400
      maximum_retry_attempts       = 185
    }
  }
}
