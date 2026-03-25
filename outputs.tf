output "iam_role_arn" {
  description = "EventBridge Scheduler用IAM RoleのARN"
  value       = aws_iam_role.scheduler_ec2.arn
}

output "schedule_group_name" {
  description = "Schedule Groupの名前"
  value       = aws_scheduler_schedule_group.ec2.name
}

output "schedule_arns" {
  description = "作成されたスケジュールのARNマップ"
  value = {
    for k, v in aws_scheduler_schedule.ec2 : k => v.arn
  }
}
