terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.56.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "your-aws-profile" # Replace with your AWS profile name

  default_tags {
    tags = {
      Project     = "boundary-multi-hop"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# Data source for latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Create TLS key pair for EC2 instances
resource "tls_private_key" "boundary_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "boundary_key" {
  key_name   = "boundary-key-${var.environment}"
  public_key = tls_private_key.boundary_key.public_key_openssh

  tags = {
    Name = "boundary-key-${var.environment}"
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.boundary_key.private_key_pem
  filename        = "${path.module}/keys/boundary-key-${var.environment}.pem"
  file_permission = "0400"
}

# Ensure keys directory exists
resource "local_file" "keys_dir" {
  content  = "# Keys directory"
  filename = "${path.module}/keys/.gitkeep"

  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/keys"
  }
}
