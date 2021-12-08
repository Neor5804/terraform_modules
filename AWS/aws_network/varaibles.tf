# set default vpc cidr block
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

# set default environment type
variable "env" {
  default = "dev"
}

# set default public subnet cidrs
variable "public_subnet_cidrs" {
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]
}

# set default private subnet cidrs
variable "private_subnet_cidrs" {
  default = [
    "10.0.11.0/24",
    "10.0.22.0/24",
    "10.0.33.0/24"
  ]
}