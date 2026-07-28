variable "owner" {
  type        = string
  description = "Owner tag to which the artifacts belong"
  default     = "lawi"
}

variable "aws_profile" {
  type        = string
  description = "AWS Profile for image"
  default     = "default"
}

variable "aws_region" {
  type        = string
  description = "AWS Region for image"
  default     = "ap-southeast-1"
}
variable "aws_instance_type" {
  type        = string
  description = "Instance Type for Image"
  default     = "t2.small"
}

variable "ami_owner_id" {
  description = "AWS Account ID that owns the base AMI (099720109477 = Canonical for Ubuntu)"
  type        = string
  default     = "099720109477"
}