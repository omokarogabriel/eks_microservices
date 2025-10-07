###create data for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

###create VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true


  tags = merge(var.common_tags, {
    Name = "${var.env_name}-vpc"
    Type = "vpc"
  })
}

###create Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.common_tags, {
    Name = "${var.env_name}-igw"
    Type = "internet-gateway"
  })
}

###create Public subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]


  tags = merge(var.common_tags, {
    Name                     = "${var.env_name}-public-subnet-${count.index + 1}"
    Type                     = "public-subnet"
    "kubernetes.io/role/elb" = "1"
  })
}

###create Private subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]


  tags = merge(var.common_tags, {
    Name                              = "${var.env_name}-private-subnet-${count.index + 1}"
    Type                              = "private-subnet"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

###create Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.common_tags, {
    Name = "${var.env_name}-public-rt"
    Type = "public-route-table"
  })
}

###create route to Internet Gateway in Public Route Table
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

###associate Public subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

###create NAT Gateway EIP
resource "aws_eip" "nat" {
  count      = var.single_nat_gateway ? 1 : length(aws_subnet.public)
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]

  tags = merge(var.common_tags, {
    Name = "${var.env_name}-nat-eip-${count.index + 1}"
    Type = "nat-eip"
  })
}

###create NAT Gateway
resource "aws_nat_gateway" "this" {
  count         = var.single_nat_gateway ? 1 : length(aws_subnet.public)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name = "${var.env_name}-nat-gw-${count.index + 1}"
    Type = "nat-gateway"
  })
  depends_on = [aws_internet_gateway.this]
}

###create Private Route Tables
resource "aws_route_table" "private" {
  count  = var.single_nat_gateway ? 1 : length(aws_subnet.private)
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = var.single_nat_gateway ? "${var.env_name}-private-rt" : "${var.env_name}-private-rt-${count.index + 1}"
    Type = "private-route-table"
  })
}

###create routes to NAT Gateway in Private Route Tables
resource "aws_route" "private_nat_gateway" {
  count                  = var.single_nat_gateway ? 1 : length(aws_subnet.private)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
}

###associate Private subnets with Private Route Tables
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

