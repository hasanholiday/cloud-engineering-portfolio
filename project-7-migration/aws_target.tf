resource "aws_vpc" "aws_target" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name       = "medcore-aws-vpc"
    Project    = "Migration"
    Compliance = "HIPAA"
    Owner      = "Hasan Holiday"
  }
}

resource "aws_internet_gateway" "aws_target" {
  vpc_id = aws_vpc.aws_target.id
  tags = { Name = "medcore-aws-igw" }
}

resource "aws_subnet" "aws_public_1" {
  vpc_id                  = aws_vpc.aws_target.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "medcore-aws-public-1" }
}

resource "aws_subnet" "aws_public_2" {
  vpc_id                  = aws_vpc.aws_target.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "medcore-aws-public-2" }
}

resource "aws_subnet" "aws_private_1" {
  vpc_id            = aws_vpc.aws_target.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "medcore-aws-private-1" }
}

resource "aws_subnet" "aws_private_2" {
  vpc_id            = aws_vpc.aws_target.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "medcore-aws-private-2" }
}

resource "aws_route_table" "aws_public" {
  vpc_id = aws_vpc.aws_target.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws_target.id
  }
  tags = { Name = "medcore-aws-public-rt" }
}

resource "aws_route_table_association" "aws_public_1" {
  subnet_id      = aws_subnet.aws_public_1.id
  route_table_id = aws_route_table.aws_public.id
}

resource "aws_route_table_association" "aws_public_2" {
  subnet_id      = aws_subnet.aws_public_2.id
  route_table_id = aws_route_table.aws_public.id
}

resource "aws_security_group" "aws_alb" {
  name   = "medcore-aws-alb-sg"
  vpc_id = aws_vpc.aws_target.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "medcore-aws-alb-sg" }
}

resource "aws_security_group" "aws_web" {
  name   = "medcore-aws-web-sg"
  vpc_id = aws_vpc.aws_target.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.aws_alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "medcore-aws-web-sg" }
}

resource "aws_security_group" "aws_db" {
  name   = "medcore-aws-db-sg"
  vpc_id = aws_vpc.aws_target.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.aws_web.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "medcore-aws-db-sg" }
}

resource "aws_s3_bucket" "medcore_files" {
  bucket = "medcore-health-files-hasan-2026"
  tags = {
    Name       = "medcore-health-files"
    Project    = "Migration"
    Compliance = "HIPAA"
  }
}

resource "aws_s3_bucket_versioning" "medcore_files" {
  bucket = aws_s3_bucket.medcore_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "medcore_files" {
  bucket = aws_s3_bucket.medcore_files.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "medcore_files" {
  bucket                  = aws_s3_bucket.medcore_files.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_lb" "aws_target" {
  name               = "medcore-aws-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.aws_alb.id]
  subnets            = [aws_subnet.aws_public_1.id, aws_subnet.aws_public_2.id]
  tags = { Name = "medcore-aws-alb" }
}

resource "aws_lb_target_group" "aws_web" {
  name     = "medcore-aws-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.aws_target.id
  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }
  tags = { Name = "medcore-aws-tg" }
}

resource "aws_lb_listener" "aws_web" {
  load_balancer_arn = aws_lb.aws_target.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_web.arn
  }
}

resource "aws_launch_template" "aws_web" {
  name_prefix   = "medcore-aws-web-"
  image_id      = "ami-0c02fb55956c7d316"
  instance_type = "t3.micro"
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.aws_web.id]
  }
  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>MedCore Health - AWS Cloud</h1>" > /var/www/html/index.html
              echo "<p>Migration Complete by Hasan Holiday</p>" >> /var/www/html/index.html
              EOF
  )
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name       = "medcore-aws-web"
      Compliance = "HIPAA"
    }
  }
}

resource "aws_autoscaling_group" "aws_web" {
  name                = "medcore-aws-asg"
  vpc_zone_identifier = [aws_subnet.aws_public_1.id, aws_subnet.aws_public_2.id]
  target_group_arns   = [aws_lb_target_group.aws_web.arn]
  health_check_type   = "ELB"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  launch_template {
    id      = aws_launch_template.aws_web.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "medcore-aws-web"
    propagate_at_launch = true
  }
}

resource "aws_db_subnet_group" "aws_target" {
  name       = "medcore-aws-db-subnet"
  subnet_ids = [aws_subnet.aws_private_1.id, aws_subnet.aws_private_2.id]
  tags = { Name = "medcore-aws-db-subnet" }
}

resource "aws_db_instance" "aws_target" {
  identifier              = "medcore-aws-database"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_encrypted       = true
  db_name                 = "medcoredb"
  username                = "medcoreadmin"
  password                = "MedCore2026Secure!"
  db_subnet_group_name    = aws_db_subnet_group.aws_target.name
  vpc_security_group_ids  = [aws_security_group.aws_db.id]
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 7
  deletion_protection     = false
  tags = {
    Name       = "medcore-aws-database"
    Compliance = "HIPAA"
    Encrypted  = "true"
  }
}

output "aws_load_balancer_url" {
  value = aws_lb.aws_target.dns_name
}

output "aws_database_endpoint" {
  value = aws_db_instance.aws_target.endpoint
}

output "aws_s3_bucket" {
  value = aws_s3_bucket.medcore_files.bucket
}
