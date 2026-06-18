resource "aws_cloudwatch_log_group" "dbt_runner" {

  name = "/ecs/${var.project_name}"
  retention_in_days = var.retention_in_days

  tags = var.tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = file("${path.module}/dashboard.json")
}

# Alarms
resource "aws_cloudwatch_metric_alarm" "run_failure" {

  alarm_name = "${var.project_name}-run-failure"

  namespace   = "WikipediaAnalysis"
  metric_name = "RunSuccess"

  statistic = "Minimum"

  period = 3600
  evaluation_periods = 1

  threshold = 0

  comparison_operator = "LessThanOrEqualToThreshold"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "no_run" {

  alarm_name = "${var.project_name}-no-run"

  namespace   = "WikipediaAnalysis"
  metric_name = "RunTotal"

  statistic = "Sum"

  period = 86400
  evaluation_periods = 2

  threshold = 1

  comparison_operator = "LessThanThreshold"

  treat_missing_data = "breaching"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "scan_volume" {

  alarm_name = "${var.project_name}-high-scan-volume"

  namespace   = "WikipediaAnalysis"
  metric_name = "GBScanned"

  statistic = "Sum"

  period = 86400
  evaluation_periods = 1

  threshold = 1000

  comparison_operator = "GreaterThanThreshold"

  alarm_actions = [var.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "long_run" {

  alarm_name = "${var.project_name}-long-run"

  namespace   = "WikipediaAnalysis"
  metric_name = "RunDurationSeconds"

  statistic = "Maximum"

  period = 3600
  evaluation_periods = 1

  threshold = 1800

  comparison_operator = "GreaterThanThreshold"

  alarm_actions = [var.sns_topic_arn]
}