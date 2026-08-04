

# VPC for simulated on-premises environment
resource "aws_vpc" "onprem" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Name        = "medcore-onprem-vpc"
    Project     = "Migration"
    Environment = "OnPremises"
    Owner       = "Hasan Holiday"
  }
}

resource "aws_internet_gateway" "onprem" {
  vpc_id = aws_vpc.onprem.id
  tags = { Name = "medcore-onprem-igw" }
}

resource "aws_subnet" "onprem" {
  vpc_id                  = aws_vpc.onprem.id
  cidr_block              = "192.168.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "medcore-onprem-subnet" }
}

resource "aws_route_table" "onprem" {
  vpc_id = aws_vpc.onprem.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.onprem.id
  }
  tags = { Name = "medcore-onprem-rt" }
}

resource "aws_route_table_association" "onprem" {
  subnet_id      = aws_subnet.onprem.id
  route_table_id = aws_route_table.onprem.id
}

resource "aws_security_group" "onprem" {
  name   = "medcore-onprem-sg"
  vpc_id = aws_vpc.onprem.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "medcore-onprem-sg" }
}

# Simulated on-premises web server
resource "aws_instance" "onprem_web" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.onprem.id
  vpc_security_group_ids = [aws_security_group.onprem.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd mysql
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>MedCore Health Patient Portal</h1>" > /var/www/html/index.html
              echo "<p>Running on: ON-PREMISES SERVER</p>" >> /var/www/html/index.html
              echo "<p>This system will be migrated to AWS</p>" >> /var/www/html/index.html
              EOF

  tags = {
    Name        = "medcore-onprem-web"
    Project     = "Migration"
    Environment = "OnPremises"
    MigrationStatus = "Pre-Migration"
  }
}

output "onprem_web_ip" {
  value = aws_instance.onprem_web.public_ip
}
