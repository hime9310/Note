# =============================================================================
# locals: スケジュール定義
# =============================================================================
locals {
  schedules = {
    weekday_start = {
      name        = "ec2-weekday-start"
      description = "平日朝9時にEC2インスタンスを起動"
      cron        = "cron(0 9 ? * MON-FRI *)"
      action      = "startInstances"
    }
    weekday_stop = {
      name        = "ec2-weekday-stop"
      description = "平日午後9時にEC2インスタンスを停止"
      cron        = "cron(0 21 ? * MON-FRI *)"
      action      = "stopInstances"
    }
    saturday_start = {
      name        = "ec2-saturday-start"
      description = "土曜日朝2時にEC2インスタンスを起動"
      cron        = "cron(0 2 ? * SAT *)"
      action      = "startInstances"
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
      for id in var.instance_ids :
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
      InstanceIds = var.instance_ids
    })

    retry_policy {
      maximum_event_age_in_seconds = 86400
      maximum_retry_attempts       = 185
    }
  }
}
