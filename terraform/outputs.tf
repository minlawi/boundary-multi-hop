# ============================================
# VPC OUTPUTS
# ============================================

output "intermediary_vpc_id" {
  description = "ID of the intermediary VPC"
  value       = aws_vpc.intermediary_vpc.id
}

output "egress_vpc_id" {
  description = "ID of the egress VPC"
  value       = aws_vpc.egress_vpc.id
}

output "vpc_peering_connection_id" {
  description = "ID of the VPC peering connection"
  value       = aws_vpc_peering_connection.intermediary_egress.id
}

# ============================================
# SUBNET OUTPUTS
# ============================================

output "intermediary_public_subnet_1_id" {
  description = "ID of intermediary public subnet 1"
  value       = aws_subnet.intermediary_public_1.id
}

output "intermediary_public_subnet_2_id" {
  description = "ID of intermediary public subnet 2"
  value       = aws_subnet.intermediary_public_2.id
}

output "intermediary_private_subnet_1_id" {
  description = "ID of intermediary private subnet 1"
  value       = aws_subnet.intermediary_private_1.id
}

output "intermediary_private_subnet_2_id" {
  description = "ID of intermediary private subnet 2"
  value       = aws_subnet.intermediary_private_2.id
}

output "egress_private_subnet_1_id" {
  description = "ID of egress private subnet 1"
  value       = aws_subnet.egress_private_1.id
}

output "egress_private_subnet_2_id" {
  description = "ID of egress private subnet 2"
  value       = aws_subnet.egress_private_2.id
}

# ============================================
# SECURITY GROUP OUTPUTS
# ============================================

output "bastion_security_group_id" {
  description = "ID of the bastion security group"
  value       = aws_security_group.bastion_sg.id
}

output "intermediary_worker_security_group_id" {
  description = "ID of the intermediary worker security group"
  value       = aws_security_group.intermediary_worker_sg.id
}

output "intermediary_target_security_group_id" {
  description = "ID of the intermediary target security group"
  value       = aws_security_group.intermediary_target_sg.id
}

output "egress_worker_security_group_id" {
  description = "ID of the egress worker security group"
  value       = aws_security_group.egress_worker_sg.id
}

output "egress_target_security_group_id" {
  description = "ID of the egress target security group"
  value       = aws_security_group.egress_target_sg.id
}

# ============================================
# EC2 INSTANCE OUTPUTS
# ============================================

output "bastion_instance_id" {
  description = "ID of the bastion instance"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion instance"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Private IP of the bastion instance"
  value       = aws_instance.bastion.private_ip
}

output "intermediary_worker_instance_id" {
  description = "ID of the intermediary worker instance"
  value       = aws_instance.intermediary_worker.id
}

output "intermediary_worker_private_ip" {
  description = "Private IP of the intermediary worker instance"
  value       = aws_instance.intermediary_worker.private_ip
}

# ============================================
# KEY PAIR OUTPUTS
# ============================================

output "key_pair_name" {
  description = "Name of the AWS key pair"
  value       = aws_key_pair.boundary_key.key_name
}

output "private_key_file_path" {
  description = "Local path to the private key file"
  value       = local_file.private_key.filename
  sensitive   = true
}

# ============================================
# SSH CONNECTION COMMANDS
# ============================================

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion host"
  value       = "ssh -i ${local_file.private_key.filename} ubuntu@${aws_instance.bastion.public_ip}"
}

output "intermediary_worker_ssh_via_bastion" {
  description = "SSH command to connect to intermediary worker via bastion (requires SSH agent forwarding)"
  value       = "ssh -J ubuntu@${aws_instance.bastion.public_ip} -i ${local_file.private_key.filename} ubuntu@${aws_instance.intermediary_worker.private_ip}"
}

output "egress_worker_ssh_via_bastion_intermediary" {
  description = "SSH command to connect to egress worker via bastion and intermediary worker (requires SSH agent forwarding)"
  value       = "ssh -J ubuntu@${aws_instance.bastion.public_ip},ubuntu@${aws_instance.intermediary_worker.private_ip} -i ${local_file.private_key.filename} ubuntu@${aws_instance.egress_worker.private_ip}"
}