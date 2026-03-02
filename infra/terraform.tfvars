project_name = "devops-tijani"
environment = "dev-env"

vpc_cidr = "10.0.0.0/16"
public_subnet1_cidr = "10.0.1.0/24"
public_subnet2_cidr = "10.0.2.0/24"
private_subnet_cidr = "10.0.4.0/24"
azs = ["us-east-1a", "us-east-1b"]

instance_type = "t3.micro"
ami_id = "ami-0532be01f26a3de55"

alb_name = "devops_alb"
igw_name = "devops_igw"
nat= "devops-nat"

public_route_cidr = "0.0.0.0/0"