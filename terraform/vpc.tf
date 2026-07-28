# ============================================
# INTERMEDIARY VPC (172.16.0.0/16)
# ============================================

resource "aws_vpc" "intermediary_vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "intermediary-vpc"
  }
}

# Public Subnets for Intermediary VPC
resource "aws_subnet" "intermediary_public_1" {
  vpc_id                  = aws_vpc.intermediary_vpc.id
  cidr_block              = "172.16.0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "intermediary-public-1"
    Type = "public"
  }
}

resource "aws_subnet" "intermediary_public_2" {
  vpc_id                  = aws_vpc.intermediary_vpc.id
  cidr_block              = "172.16.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "intermediary-public-2"
    Type = "public"
  }
}

# Private Subnets for Intermediary VPC
resource "aws_subnet" "intermediary_private_1" {
  vpc_id            = aws_vpc.intermediary_vpc.id
  cidr_block        = "172.16.128.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "intermediary-private-1"
    Type = "private"
  }
}

resource "aws_subnet" "intermediary_private_2" {
  vpc_id            = aws_vpc.intermediary_vpc.id
  cidr_block        = "172.16.129.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "intermediary-private-2"
    Type = "private"
  }
}

# Internet Gateway for Intermediary VPC
resource "aws_internet_gateway" "intermediary_igw" {
  vpc_id = aws_vpc.intermediary_vpc.id

  tags = {
    Name = "intermediary-igw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "intermediary_nat_eip" {
  domain = "vpc"

  tags = {
    Name = "intermediary-nat-eip"
  }

  depends_on = [aws_internet_gateway.intermediary_igw]
}

# NAT Gateway for Intermediary VPC
resource "aws_nat_gateway" "intermediary_nat" {
  allocation_id = aws_eip.intermediary_nat_eip.id
  subnet_id     = aws_subnet.intermediary_public_1.id

  tags = {
    Name = "intermediary-nat-gateway"
  }

  depends_on = [aws_internet_gateway.intermediary_igw]
}

# ============================================
# EGRESS VPC (192.168.0.0/16)
# ============================================

resource "aws_vpc" "egress_vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "egress-vpc"
  }
}

# Private Subnets for Egress VPC
resource "aws_subnet" "egress_private_1" {
  vpc_id            = aws_vpc.egress_vpc.id
  cidr_block        = "192.168.128.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "egress-private-1"
    Type = "private"
  }
}

resource "aws_subnet" "egress_private_2" {
  vpc_id            = aws_vpc.egress_vpc.id
  cidr_block        = "192.168.129.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "egress-private-2"
    Type = "private"
  }
}

# ============================================
# ROUTE TABLES - INTERMEDIARY VPC
# ============================================

# Public Route Table
resource "aws_route_table" "intermediary_public_rt" {
  vpc_id = aws_vpc.intermediary_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.intermediary_igw.id
  }

  tags = {
    Name = "intermediary-public-rt"
  }
}

resource "aws_route_table_association" "intermediary_public_1" {
  subnet_id      = aws_subnet.intermediary_public_1.id
  route_table_id = aws_route_table.intermediary_public_rt.id
}

resource "aws_route_table_association" "intermediary_public_2" {
  subnet_id      = aws_subnet.intermediary_public_2.id
  route_table_id = aws_route_table.intermediary_public_rt.id
}

# Private Route Table 1 (routes managed separately)
resource "aws_route_table" "intermediary_private_rt_1" {
  vpc_id = aws_vpc.intermediary_vpc.id

  tags = {
    Name = "intermediary-private-rt-1"
  }
}

# Default route to NAT Gateway (for HCP Boundary registration)
resource "aws_route" "intermediary_private_rt_1_default" {
  route_table_id         = aws_route_table.intermediary_private_rt_1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.intermediary_nat.id

  depends_on = [aws_nat_gateway.intermediary_nat]
}

# Route to egress-vpc via VPC peering
resource "aws_route" "intermediary_private_rt_1_to_egress" {
  route_table_id            = aws_route_table.intermediary_private_rt_1.id
  destination_cidr_block    = aws_vpc.egress_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.intermediary_egress.id

  depends_on = [aws_vpc_peering_connection.intermediary_egress]
}

resource "aws_route_table_association" "intermediary_private_1" {
  subnet_id      = aws_subnet.intermediary_private_1.id
  route_table_id = aws_route_table.intermediary_private_rt_1.id
}

# Private Route Table 2 (NO default route)
resource "aws_route_table" "intermediary_private_rt_2" {
  vpc_id = aws_vpc.intermediary_vpc.id

  tags = {
    Name = "intermediary-private-rt-2"
  }
}

# Route to egress-vpc via VPC peering
resource "aws_route" "intermediary_private_rt_2_to_egress" {
  route_table_id            = aws_route_table.intermediary_private_rt_2.id
  destination_cidr_block    = aws_vpc.egress_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.intermediary_egress.id
}

resource "aws_route_table_association" "intermediary_private_2" {
  subnet_id      = aws_subnet.intermediary_private_2.id
  route_table_id = aws_route_table.intermediary_private_rt_2.id
}

# ============================================
# ROUTE TABLES - EGRESS VPC
# ============================================

# Private Route Table 1
resource "aws_route_table" "egress_private_rt_1" {
  vpc_id = aws_vpc.egress_vpc.id

  tags = {
    Name = "egress-private-rt-1"
  }
}

# Route to intermediary-vpc via VPC peering
resource "aws_route" "egress_private_rt_1_to_intermediary" {
  route_table_id            = aws_route_table.egress_private_rt_1.id
  destination_cidr_block    = aws_vpc.intermediary_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.intermediary_egress.id
}

resource "aws_route_table_association" "egress_private_1" {
  subnet_id      = aws_subnet.egress_private_1.id
  route_table_id = aws_route_table.egress_private_rt_1.id
}

# Private Route Table 2
resource "aws_route_table" "egress_private_rt_2" {
  vpc_id = aws_vpc.egress_vpc.id

  tags = {
    Name = "egress-private-rt-2"
  }
}

# Route to intermediary-vpc via VPC peering
resource "aws_route" "egress_private_rt_2_to_intermediary" {
  route_table_id            = aws_route_table.egress_private_rt_2.id
  destination_cidr_block    = aws_vpc.intermediary_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.intermediary_egress.id
}

resource "aws_route_table_association" "egress_private_2" {
  subnet_id      = aws_subnet.egress_private_2.id
  route_table_id = aws_route_table.egress_private_rt_2.id
}

# ============================================
# VPC PEERING
# ============================================

resource "aws_vpc_peering_connection" "intermediary_egress" {
  vpc_id      = aws_vpc.intermediary_vpc.id
  peer_vpc_id = aws_vpc.egress_vpc.id
  auto_accept = true

  tags = {
    Name = "intermediary-egress-peering"
  }
}
