variable "project_name" {
    description = "my project"
  type = string
}

variable "environment" {
    description = "this dev enviroment"
    type = string
  
}

variable "vpc_cidr" {
    description = "vpc cidr block"
    type = string
  
}

variable "public_subnet1_cidr" {
    description = "public_subnet1_cidr"
    type = string
  
}

variable "public_subnet2_cidr" {
    description = "public_subnet2"
  
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  
}

variable "private_subnet_cidr" {
    description = "private_subnet1"
    type = string
}


variable "instance_type" {
    description = "ec2 instance type"
    type = string
}

variable "ami_id" {
    description = "amazon linux machine ID"
    type = string
  
}

variable "alb_name" {
    description = "application load balancer"
    type = string
    
  
}

variable "igw_name" {
    description = "internet gateway dev"
    type = string
  
}

variable "nat" {
    description = "nat gateway name"
    type = string
  
}

variable "public_route_cidr" {
    description = "public route cidr"
    type = string
  
}



