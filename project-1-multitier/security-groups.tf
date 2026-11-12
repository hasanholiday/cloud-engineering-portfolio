# Load Balancer Security Group — accepts traffic from internet
resource "aws_security_group" "alb" {
  name        = "project1-alb-sg"
  description = "Allow HTTP from internet"
  vpc_id      = aws_vpc.main.id

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

  tags = {
    Name    = "project1-alb-sg"
    Project = "MultiTierApp"
  }
}

# Web Server Security Group — only accepts traffic from load balancer
resource "aws_security_group" "web" {
  name        = "project1-web-sg"
  description = "Allow HTTP from ALB only (no SSH)"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "project1-web-sg"
    Project = "MultiTierApp"
  }
}

# Database Security Group — only accepts traffic from web servers
resource "aws_security_group" "database" {
  name        = "project1-db-sg"
  description = "Allow MySQL from web servers only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "project1-db-sg"
    Project = "MultiTierApp"
  }
}
