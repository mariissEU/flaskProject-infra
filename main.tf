# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
terraform {
  required_version = "1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.20"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-1"
}

# Create vpc
resource "aws_vpc" "maris-test-vpc" {
  cidr_block = "172.196.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "maris-test-vpc_TF"
    Owner = "Maris Liepins"
  }
}

# Create route table for the VPC
resource "aws_route_table" "maris-test-route-table" {
  vpc_id = aws_vpc.maris-test-vpc.id

  route {
    cidr_block = aws_vpc.maris-test-vpc.cidr_block
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.maris-test-gw.id
  }

  tags = {
    Name = "maris-test-RT_TF"
    Owner = "Maris Liepins"
  }
}

resource "aws_main_route_table_association" "association" {
  vpc_id         = aws_vpc.maris-test-vpc.id
  route_table_id = aws_route_table.maris-test-route-table.id
}

# Create Internet GW
resource "aws_internet_gateway" "maris-test-gw" {
  vpc_id = aws_vpc.maris-test-vpc.id

  tags = {
    Name = "maris-test-GW_TF"
    Owner = "Maris Liepins"
  }
}

resource "aws_subnet" "maris-test-subnet" {
  vpc_id     = aws_vpc.maris-test-vpc.id
  cidr_block = "172.196.1.0/24"
  map_public_ip_on_launch = "true"
  tags = {
    Name = "maris-test-subnet_TF"
    Owner = "Maris Liepins"
  }
}

# Create Security group
resource "aws_security_group" "maris-test-sg" {
  name        = "maris-test-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.maris-test-vpc.id

  ingress {
      description      = "SSH from Public"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }

  ingress {
      description      = "App wise Ports specific to local"
      from_port        = 1000
      to_port          = 9999
      protocol         = "tcp"
      cidr_blocks      = ["212.18.129.200/32"]
    }  

  ingress {
      description      = "TLS from Public"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }

  ingress {
      description      = "HTTP from Public"
      from_port        = 8080
      to_port          = 8080
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
    
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "maris-test-sg_TF"
    Owner = "Maris Liepins"
  }
}

# Create S3 bucket
resource "aws_s3_bucket" "maris-test-s3-bucket" {
  bucket = "maris-test-s3-bucket"

  tags = {
    Name = "maris-test-s3-bucket_TF"
    Owner = "Maris Liepins"
  }
}

resource "aws_s3_bucket_versioning" "S3_versioning" {
  bucket = aws_s3_bucket.maris-test-s3-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.maris-test-s3-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_access_point" "maris-test-ap" {
  bucket = aws_s3_bucket.maris-test-s3-bucket.id
  name   = "maris-test-ap"

  # VPC must be specified for S3 on Outposts
  vpc_configuration {
    vpc_id = aws_vpc.maris-test-vpc.id
  }
}

# Create aws instance
resource "aws_instance" "maris-test-ec2instance" {
  ami           = "ami-0f8e81a3da6e2510a"
  instance_type = "t2.medium"
  count = "1"
  key_name = "marisL"
  associate_public_ip_address = true
  subnet_id     = aws_subnet.maris-test-subnet.id
  vpc_security_group_ids = [
    aws_security_group.maris-test-sg.id
  ]
  tags = {
    Name = "TF - testInstanceML"
    Owner = "Maris Liepins"
  }
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = false
    delete_on_termination = true
  }

  user_data = "${file("init.sh")}"

}
