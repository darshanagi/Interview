resource "aws_instance" "example" {
  ami           = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type = "t3.micro"

  tags = {
    Name = "HelloWorld"
  }
}

======================================================================================

resource "aws_s3_bucket" "my-s3-bucket" {
  bucket_prefix = var.bucket_prefix
  tags = var.tags
}


resource "aws_s3_bucket_versioning" "my-s3-bucket-versioning" {
  bucket = aws_s3_bucket.my-s3-bucket.id
  versioning_configuration {
    status = var.versioning ? "Enabled" : "Suspended"
  }
}

=======================================================================================

provider "aws" {
  region = "ap-south-1"
}

# -----------------------
# VPC
# -----------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

# Private Subnet
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "private-subnet-1"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Route Table Association
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

# -----------------------
# Security Group
# -----------------------
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Allow MySQL access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # restrict in real use
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------
# RDS Subnet Group
# -----------------------
resource "aws_db_subnet_group" "rds_subnet" {
  name       = "rds-subnet-group"
  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.public_1.id
  ]

  tags = {
    Name = "rds-subnet-group"
  }
}

# -----------------------
# RDS Instance
# -----------------------
resource "aws_db_instance" "mysql" {
  identifier        = "mydb-instance"
  engine            = "mysql"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "mydb"
  username = "admin"
  password = "StrongPassword123!"  # use secrets manager in real use

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet.name

  skip_final_snapshot = true
  publicly_accessible = false

  tags = {
    Name = "my-rds-instance"
  }
}
