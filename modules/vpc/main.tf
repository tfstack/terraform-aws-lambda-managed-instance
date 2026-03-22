locals {
  az_count = length(var.availability_zones)

  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    { Name = var.vpc_name },
    var.tags
  )
}

resource "aws_internet_gateway" "this" {
  count = length(var.public_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    { Name = "${var.vpc_name}-igw" },
    var.tags
  )
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name = "${var.vpc_name}-public-${count.index + 1}"
      Type = "public"
    },
    var.tags
  )
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    {
      Name = "${var.vpc_name}-private-${count.index + 1}"
      Type = "private"
    },
    var.tags
  )
}

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = merge(
    { Name = "${var.vpc_name}-nat-eip-${count.index + 1}" },
    var.tags
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    { Name = "${var.vpc_name}-nat-${count.index + 1}" },
    var.tags
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(
    {
      Name = "${var.vpc_name}-public-rt-${count.index + 1}"
      Type = "public"
    },
    var.tags
  )
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
    }
  }

  tags = merge(
    {
      Name = "${var.vpc_name}-private-rt-${count.index + 1}"
      Type = "private"
    },
    var.tags
  )
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
