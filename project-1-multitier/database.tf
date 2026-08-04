# DB Subnet Group — tells RDS which subnets to use
resource "aws_db_subnet_group" "main" {
  name       = "project1-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name    = "project1-db-subnet-group"
    Project = "MultiTierApp"
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier             = "project1-database"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  storage_encrypted      = true
  db_name                = "appdb"
  username               = "admin"
  password               = "SecurePass123!"
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = {
    Name        = "project1-database"
    Project     = "MultiTierApp"
    Environment = "Production"
    Encrypted   = "true"
    Compliance  = "HIPAA-Ready"
  }
}
