variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into bastion host"
  type        = string
  default     = "0.0.0.0/0"
}

variable "hcp_boundary_cluster_id" {
  description = "HCP Boundary Cluster ID for intermediary worker"
  type        = string
  sensitive   = true
}

variable "hcp_worker_cidr" {
  description = "CIDR block or IP of HCP-managed worker nodes"
  type        = string
  default     = "10.0.0.0/8"
}

variable "instance_type" {
  description = "EC2 instance type for all instances"
  type        = string
  default     = "t3.micro"
}

variable "boundary_version" {
  description = "HashiCorp Boundary version to install"
  type        = string
  default     = "latest"
}

# ============================================
# CUSTOM AMI IDs (from Packer)
# ============================================

variable "intermediary_worker_ami_id" {
  description = "AMI ID for intermediary worker (set by Packer or manually)"
  type        = string
  default     = ""
}

variable "egress_worker_ami_id" {
  description = "AMI ID for egress worker (set by Packer or manually)"
  type        = string
  default     = ""
}