# Application Load Balancer
resource "aws_lb" "main" {
  name               = "project1-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name        = "project1-alb"
    Project     = "MultiTierApp"
    Environment = "Production"
  }
}

# Target Group — where load balancer sends traffic
resource "aws_lb_target_group" "web" {
  name     = "project1-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }

  tags = {
    Name    = "project1-tg"
    Project = "MultiTierApp"
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Launch Template — blueprint for web servers
resource "aws_launch_template" "web" {
  name_prefix   = "project1-web-"
  image_id      = "ami-0c02fb55956c7d316"
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Project 1 - Multi-Tier App by Hasan Holiday</h1>" > /var/www/html/index.html
              echo "<p>Server: $(hostname)</p>" >> /var/www/html/index.html
              echo "<p>Built with Terraform - HIPAA Ready Architecture</p>" >> /var/www/html/index.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "project1-web-server"
      Project     = "MultiTierApp"
      Environment = "Production"
      Owner       = "Hasan Holiday"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                = "project1-asg"
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "project1-web-server"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "MultiTierApp"
    propagate_at_launch = true
  }
}

# Auto Scaling Policy — scale up when CPU is high
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "project1-scale-up"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

# Auto Scaling Policy — scale down when CPU is low
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "project1-scale-down"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}
