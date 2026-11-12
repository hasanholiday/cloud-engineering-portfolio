# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "project1-vpc"
    Project     = "MultiTierApp"
    Environment = "Production"
    Owner       = "Hasan Holiday"
    CostCenter  = "CloudEngineering"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "project1-igw"
    Project     = "MultiTierApp"
    Environment = "Production"
  }
}

# Public Subnet 1 — AZ 1
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "project1-public-subnet-1"
    Project     = "MultiTierApp"
    Environment = "Production"
    Tier        = "Public"
  }
}

# Public Subnet 2 — AZ 2
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "project1-public-subnet-2"
    Project     = "MultiTierApp"
    Environment = "Production"
    Tier        = "Public"
  }
}

# Private Subnet 1 — AZ 1 — Database lives here
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name        = "project1-private-subnet-1"
    Project     = "MultiTierApp"
    Environment = "Production"
    Tier        = "Private"
  }
}

# Private Subnet 2 — AZ 2 — Database lives here
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name        = "project1-private-subnet-2"
    Project     = "MultiTierApp"
    Environment = "Production"
    Tier        = "Private"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "project1-public-rt"
    Project = "MultiTierApp"
  }
}

# Associate public subnets with route table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for the NAT gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "project1-nat-eip"
    Project = "MultiTierApp"
  }
}

# NAT Gateway — lets private servers reach the internet (updates, packages) with no inbound path.
# Trade-off: one NAT in one AZ keeps cost down (~$32/month + data). If AZ 1 fails, private egress stops.
# Production fix: one NAT per AZ.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name    = "project1-nat"
    Project = "MultiTierApp"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route table for private subnets — outbound via NAT only
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name    = "project1-private-rt"
    Project = "MultiTierApp"
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}
