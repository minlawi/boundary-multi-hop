# ============================================
# INTERMEDIARY VPC EC2 INSTANCES
# ============================================

# Bastion Instance - Public Subnet 1
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.intermediary_public_1.id
  key_name               = aws_key_pair.boundary_key.key_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  associate_public_ip_address = true

  source_dest_check = true

  metadata_options {
    http_tokens            = "required"
    http_protocol_ipv6     = "enabled"
    instance_metadata_tags = "enabled"
  }

  tags = {
    Name = "bastion-instance"
    Role = "bastion"
    VPC  = "intermediary"
  }
}

# Intermediary Worker - Private Subnet 1
resource "aws_instance" "intermediary_worker" {
  ami                    = var.intermediary_worker_ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.intermediary_private_1.id
  key_name               = aws_key_pair.boundary_key.key_name
  vpc_security_group_ids = [aws_security_group.intermediary_worker_sg.id]

  associate_public_ip_address = false

  source_dest_check = true

  metadata_options {
    http_tokens            = "required"
    http_protocol_ipv6     = "enabled"
    instance_metadata_tags = "enabled"
  }

  # User data to configure Boundary worker
  user_data = templatefile("${path.module}/templates/intermediary_worker_user_data.sh", {
    hcp_boundary_cluster_id = var.hcp_boundary_cluster_id
  })

  tags = {
    Name = "intermediary-worker"
    Role = "worker"
    VPC  = "intermediary"
  }

  # Wait for bastion to be ready
  depends_on = [aws_instance.bastion]
}

# Intermediary Target - Private Subnet 2 (isolated)
resource "aws_instance" "intermediary_target" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.intermediary_private_2.id
  key_name               = aws_key_pair.boundary_key.key_name
  vpc_security_group_ids = [aws_security_group.intermediary_target_sg.id]

  associate_public_ip_address = false

  source_dest_check = true

  metadata_options {
    http_tokens            = "required"
    http_protocol_ipv6     = "enabled"
    instance_metadata_tags = "enabled"
  }

  tags = {
    Name = "intermediary-target"
    Role = "target"
    VPC  = "intermediary"
  }
}

# ============================================
# EGRESS VPC EC2 INSTANCES
# ============================================

# Egress Worker - Private Subnet 1
resource "aws_instance" "egress_worker" {
  ami                    = "ami-04523a08824f7513f"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.egress_private_1.id
  key_name               = aws_key_pair.boundary_key.key_name
  vpc_security_group_ids = [aws_security_group.egress_worker_sg.id]

  associate_public_ip_address = false

  source_dest_check = true

  metadata_options {
    http_tokens            = "required"
    http_protocol_ipv6     = "enabled"
    instance_metadata_tags = "enabled"
  }

  # User data to configure Boundary worker
  user_data = templatefile("${path.module}/templates/egress_worker_user_data.sh", {
    intermediary_worker_private_ip = aws_instance.intermediary_worker.private_ip
  })

  tags = {
    Name                     = "egress-worker"
    Role                     = "worker"
    VPC                      = "egress"
    "intermediary-worker-ip" = aws_instance.intermediary_worker.private_ip
  }

  # Wait for intermediary worker to be ready
  depends_on = [aws_instance.intermediary_worker]
}

# Egress Target - Private Subnet 1
resource "aws_instance" "egress_target" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.egress_private_1.id
  key_name               = aws_key_pair.boundary_key.key_name
  vpc_security_group_ids = [aws_security_group.egress_target_sg.id]

  associate_public_ip_address = false

  source_dest_check = true

  metadata_options {
    http_tokens            = "required"
    http_protocol_ipv6     = "enabled"
    instance_metadata_tags = "enabled"
  }

  tags = {
    Name = "egress-target"
    Role = "target"
    VPC  = "egress"
  }

  # Wait for egress worker to be ready
  depends_on = [aws_instance.egress_worker]
}
