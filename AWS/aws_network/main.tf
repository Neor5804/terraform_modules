#----------------------------------------------------------
# My first Terraform module
# Provision:
#  - VPC
#  - Internet Gateway
#  - XX Public Subnets
#  - XX Private Subnets
#  - XX NAT Gateways in Public Subnets to give access to Internet from Private Subnets
#  - XX Route tables for public and private subnets
#
# Made by Vadim Bykov
#----------------------------------------------------------

# Get available availability zones
data "aws_availability_zones" "available" {}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.env}-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-igw"
  }
}

#----------------Public Subnets and Routing----------------

# Creating public subnets
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)                          // takes the length(number) of cidr blocks given in a variable "public_subnet_cidrs"
  vpc_id                  = aws_vpc.main.id                                          // in which VPC the networks will be created
  cidr_block              = element(var.public_subnet_cidrs, count.index)            // takes each element(cider block) from a variable "public_subnet_cidrs"
  availability_zone       = data.aws_availability_zones.available.names[count.index] // in which availability zone the network will be created
  map_public_ip_on_launch = true                                                     // getting public IP at start
  tags = {
    Name = "${var.env}-public-${count.index + 1}"
  }
}

# Creation of only ONE route table with a single route to the Internet through the Internet gateway
resource "aws_route_table" "public_subnets_rt" {
  vpc_id = aws_vpc.main.id // in which VPC route table will be created
  route {
    cidr_block = "0.0.0.0/0"                  // destination(route to internet)
    gateway_id = aws_internet_gateway.main.id // target(go through internet gateway)
  }
  tags = {
    Name = "${var.env}-route-public-subnet"
  }
}

# Create a public subnet association (attaching one route table to each public subnet created)
resource "aws_route_table_association" "public_routes" {
  count          = length(aws_subnet.public_subnets[*].id)               // get count of created public subnets and make the association as many times as there are public subnets
  route_table_id = aws_route_table.public_subnets_rt.id                  // which route table to use for association
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index) // takes each element(public subnet id) from list and and take one index at a time"
}

#--------------NAT Gateways with Elastic IPs for private Subnets---------------

# Creating EIP addresses for each NAT gateway
resource "aws_eip" "eip_for_nat_gw" {
  count = length(var.private_subnet_cidrs) // number of addresses equal to the number of private subnets
  vpc   = true
  tags = {
    Name = "${var.env}-eip-for-nat-gw-${count.index + 1}"
  }
}

# Creating NAT Gateways for each private subnet cidr block
resource "aws_nat_gateway" "nat_gw" {
  count         = length(var.private_subnet_cidrs)                      // number of nat gateways equal to the number of cidr blocks of the private subnet
  allocation_id = aws_eip.eip_for_nat_gw[count.index].id                // the allocation ID of the Elastic IP address for the gateway
  subnet_id     = element(aws_subnet.public_subnets[*].id, count.index) // the subnet ID of the subnet in which to place the gateway
  tags = {
    Name = "${var.env}-nat-gw-${count.index + 1}"
  }
}

#----------------Private Subnets and Routing----------------

# Creating private subnets
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)                         // takes the length(number) of cidr blocks given in a variable "private_subnet_cidrs"
  cidr_block        = element(var.private_subnet_cidrs, count.index)           // takes each element(cider block) from a variable "public_subnet_cidrs"
  vpc_id            = aws_vpc.main.id                                          // in which VPC the private networks will be created
  availability_zone = data.aws_availability_zones.available.names[count.index] // in which availability zone the network will be created
  tags = {
    Name = "${var.env}-private-${count.index + 1}"
  }
}

# Create routing tables for each private subnet cidr block
resource "aws_route_table" "private_subnets_rt" {
  count  = length(var.private_subnet_cidrs) // the number of route tables is equal to the number of cidr blocks of the private subnet
  vpc_id = aws_vpc.main.id                  // in which VPC route tables will be created
  route {
    cidr_block = "0.0.0.0/0"                            // destination(route to internet)
    gateway_id = aws_nat_gateway.nat_gw[count.index].id // target(go through NAT gateway)
  }
  tags = {
    Name = "${var.env}-route-private-subnet-${count.index + 1}"
  }
}

# Creating private subnet associations (attach each private route table to each created private subnet)
resource "aws_route_table_association" "private_routes" {
  count          = length(aws_subnet.private_subnets[*].id)               // get count of created private subnets and make the association as many times as there are private subnets
  route_table_id = aws_route_table.private_subnets_rt[count.index].id     // which route table to use for association
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index) // takes each element(private subnet id) from list and take one index at a time"
}
