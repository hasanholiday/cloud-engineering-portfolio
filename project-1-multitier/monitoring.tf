# CloudWatch Alarm — High CPU triggers scale up
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "project1-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale up when CPU exceeds 70 percent"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  tags = {
    Name    = "project1-cpu-high-alarm"
    Project = "MultiTierApp"
  }
}

# CloudWatch Alarm — Low CPU triggers scale down
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "project1-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "Scale down when CPU drops below 20 percent"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  tags = {
    Name    = "project1-cpu-low-alarm"
    Project = "MultiTierApp"
  }
}

# CloudWatch Alarm — Monitor load balancer response time
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "project1-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 120
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when response time exceeds 1 second"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name    = "project1-alb-response-alarm"
    Project = "MultiTierApp"
  }
}
