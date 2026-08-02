data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  common_tags = merge(
    {
      "Name"      = var.name
      "ManagedBy" = "terraform"
    },
    var.tags
  )
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.common_tags,
    {
      "Component" = "vpc"
    }
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    local.common_tags,
    {
      "Component" = "igw"
    }
  )
}

# Public subnets
resource "aws_subnet" "public" {
  for_each = {
    for idx, az in local.azs :
    idx => {
      az   = az
      cidr = var.public_subnet_cidrs[idx]
    }
  }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      "Component" = "public-subnet"
      "AZ"        = each.value.az
      "Tier"      = "public"
    }
  )
}

# Private subnets
resource "aws_subnet" "private" {
  for_each = {
    for idx, az in local.azs :
    idx => {
      az   = az
      cidr = var.private_subnet_cidrs[idx]
    }
  }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    local.common_tags,
    {
      "Component" = "private-subnet"
      "AZ"        = each.value.az
      "Tier"      = "private"
    }
  )
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    local.common_tags,
    {
      "Component" = "public-rt"
      "Tier"      = "public"
    }
  )
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT gateways (support single or per-AZ)
resource "aws_eip" "nat" {
  count = var.single_nat_gateway ? 1 : length(aws_subnet.public)

  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      "Component" = "nat-eip"
    }
  )
}

resource "aws_nat_gateway" "this" {
  count = var.single_nat_gateway ? 1 : length(aws_subnet.public)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = element(values(aws_subnet.public)[*].id, var.single_nat_gateway ? 0 : count.index)

  tags = merge(
    local.common_tags,
    {
      "Component" = "nat-gw"
    }
  )

  depends_on = [aws_internet_gateway.this]
}

# Private route tables (one per private subnet, mapped to NAT)
resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  tags = merge(
    local.common_tags,
    {
      "Component" = "private-rt"
      "Tier"      = "private"
    }
  )
}

resource "aws_route" "private_internet_access" {
  for_each = aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[tonumber(each.key)].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}