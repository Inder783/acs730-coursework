data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "acs730-assignment1-${var.environment}"

  public_subnets = {
    a = {
      cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
      availability_zone = data.aws_availability_zones.available.names[0]
    }
    b = {
      cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
      availability_zone = data.aws_availability_zones.available.names[1]
    }
  }

  ingress_rules = [
    {
      description = "HTTP from anywhere"
      port        = 80
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  common_tags = {
    Course      = "ACS730"
    Assignment  = "assignment1"
    Environment = var.environment
    Managed     = "terraform"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${local.name}-vpc" })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, { Name = "${local.name}-public-${each.key}" })
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name}-igw" })
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.name}-public-rt" })
}
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
resource "aws_security_group" "web" {
  name        = "${local.name}-web"
  description = "Web ingress for ACS730 Assignment 1"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = local.ingress_rules

    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name}-web-sg" })
}
