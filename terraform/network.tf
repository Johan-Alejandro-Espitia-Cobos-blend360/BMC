# VPC, subredes públicas/privadas (2 AZs), Internet Gateway, NAT Gateway y
# tablas de rutas. Equivalente a la sección de red de
# cloudformation/langflow-ecs.yaml.

locals {
  # Replica Fn::Cidr [VpcCidr, 4, 8]: 4 subredes, cada una con 8 bits de host
  # (es decir, /24 cuando VpcCidr es /16, igual que en el template CFN).
  vpc_prefix_length = tonumber(split("/", var.vpc_cidr)[1])
  subnet_newbits    = 24 - local.vpc_prefix_length
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.stack_name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.stack_name}-igw"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 0)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.stack_name}-public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = data.aws_availability_zones.available.names[1]
  cidr_block              = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 1)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.stack_name}-public-2"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 2)
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.stack_name}-private-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = data.aws_availability_zones.available.names[1]
  cidr_block              = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 3)
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.stack_name}-private-2"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.stack_name}-public-rt"
  }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_1" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_1.id
}

resource "aws_route_table_association" "public_2" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_2.id
}

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "${var.stack_name}-nat"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.stack_name}-private-rt"
  }
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private_1" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private_1.id
}

resource "aws_route_table_association" "private_2" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private_2.id
}
