# ============================================
# SECURITY GROUPS - INTERMEDIARY VPC
# ============================================

resource "aws_security_group" "intermediary_worker_sg" {
  name        = "intermediary-worker-sg"
  description = "Security group for intermediary worker"
  vpc_id      = aws_vpc.intermediary_vpc.id

  tags = {
    Name = "intermediary-worker-sg"
  }
}

resource "aws_security_group" "intermediary_target_sg" {
  name        = "intermediary-target-sg"
  description = "Security group for intermediary target"
  vpc_id      = aws_vpc.intermediary_vpc.id

  tags = {
    Name = "intermediary-target-sg"
  }
}

# ============================================
# SECURITY GROUPS - EGRESS VPC
# ============================================

resource "aws_security_group" "egress_worker_sg" {
  name        = "egress-worker-sg"
  description = "Security group for egress worker"
  vpc_id      = aws_vpc.egress_vpc.id

  tags = {
    Name = "egress-worker-sg"
  }
}

resource "aws_security_group" "egress_target_sg" {
  name        = "egress-target-sg"
  description = "Security group for egress target"
  vpc_id      = aws_vpc.egress_vpc.id

  tags = {
    Name = "egress-target-sg"
  }
}

# ============================================
# BASTION SECURITY GROUP (Intermediary VPC)
# ============================================

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.intermediary_vpc.id

  tags = {
    Name = "bastion-sg"
  }
}

# ============================================
# SECURITY GROUP RULES - BASTION
# ============================================

# Ingress: SSH from user's IP
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_from_user" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  description       = "Allow SSH from user IP"
}

# Egress: All outbound
resource "aws_vpc_security_group_egress_rule" "bastion_all_outbound" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

# ============================================
# SECURITY GROUP RULES - INTERMEDIARY WORKER
# ============================================

# Ingress: SSH from bastion
resource "aws_vpc_security_group_ingress_rule" "intermediary_worker_ssh_from_bastion" {
  security_group_id            = aws_security_group.intermediary_worker_sg.id
  referenced_security_group_id = aws_security_group.bastion_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
  description                  = "Allow SSH from bastion"
}

# Ingress: TCP/9202 from egress-worker (downstream)
resource "aws_vpc_security_group_ingress_rule" "intermediary_worker_9202_from_egress" {
  security_group_id            = aws_security_group.intermediary_worker_sg.id
  referenced_security_group_id = aws_security_group.egress_worker_sg.id
  from_port                    = 9202
  ip_protocol                  = "tcp"
  to_port                      = 9202
  description                  = "Allow Boundary proxy from egress worker"
}

# Egress: TCP/9202 to HCP-managed worker nodes (upstream)
resource "aws_vpc_security_group_egress_rule" "intermediary_worker_9202_to_hcp" {
  security_group_id = aws_security_group.intermediary_worker_sg.id
  cidr_ipv4         = var.hcp_worker_cidr
  from_port         = 9202
  ip_protocol       = "tcp"
  to_port           = 9202
  description       = "Allow Boundary proxy to HCP workers"
}

# Egress: SSH to intermediary-target
resource "aws_vpc_security_group_egress_rule" "intermediary_worker_ssh_to_target" {
  security_group_id            = aws_security_group.intermediary_worker_sg.id
  referenced_security_group_id = aws_security_group.intermediary_target_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
  description                  = "Allow SSH to intermediary target"
}

# Egress: SSH to egress-worker
resource "aws_vpc_security_group_egress_rule" "intermediary_worker_ssh_to_egress_worker" {
  security_group_id            = aws_security_group.intermediary_worker_sg.id
  referenced_security_group_id = aws_security_group.egress_worker_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
  description                  = "Allow SSH to egress worker"
}

# ============================================
# SECURITY GROUP RULES - INTERMEDIARY TARGET
# ============================================

# Ingress: SSH from intermediary-worker
resource "aws_vpc_security_group_ingress_rule" "intermediary_target_ssh_from_worker" {
  security_group_id            = aws_security_group.intermediary_target_sg.id
  referenced_security_group_id = aws_security_group.intermediary_worker_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
  description                  = "Allow SSH only from intermediary worker"
}


# ============================================
# SECURITY GROUP RULES - EGRESS WORKER
# ============================================

# Ingress: SSH from intermediary-worker
resource "aws_vpc_security_group_ingress_rule" "egress_worker_ssh_from_intermediary" {
  security_group_id            = aws_security_group.egress_worker_sg.id
  referenced_security_group_id = aws_security_group.intermediary_worker_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
  description                  = "Allow SSH from intermediary worker"
}

# Egress: TCP/9202 to intermediary-worker (upstream)
resource "aws_vpc_security_group_egress_rule" "egress_worker_9202_to_intermediary" {
  security_group_id            = aws_security_group.egress_worker_sg.id
  referenced_security_group_id = aws_security_group.intermediary_worker_sg.id
  from_port                    = 9202
  ip_protocol                  = "tcp"
  to_port                      = 9202
  description                  = "Allow Boundary proxy to intermediary worker"
}

# Egress: SSH to egress-target
resource "aws_vpc_security_group_egress_rule" "egress_worker_ssh_to_target" {
  security_group_id            = aws_security_group.egress_worker_sg.id
  referenced_security_group_id = aws_security_group.egress_target_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
  description                  = "Allow SSH to egress target"
}

# ============================================
# SECURITY GROUP RULES - EGRESS TARGET
# ============================================

# Ingress: SSH from egress-worker
resource "aws_vpc_security_group_ingress_rule" "egress_target_ssh_from_worker" {
  security_group_id            = aws_security_group.egress_target_sg.id
  referenced_security_group_id = aws_security_group.egress_worker_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
  description                  = "Allow SSH only from egress worker"
}

