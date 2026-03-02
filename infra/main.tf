terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.31.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
} 


resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "${var.project_name}-vpc"
    Environment = var.environment
  
  }
  
}

resource "aws_internet_gateway" "igw_name" {
  vpc_id = aws_vpc.main.id

depends_on = [ aws_vpc.main ]
  tags = {
    Name = var.igw_name
    Environment = var.environment
  }
  
}

resource "aws_subnet" "public_subnet1_cidr" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnet1_cidr
  availability_zone = var.azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-1"
    environment = var.environment
  }

}

resource "aws_subnet" "public_subnet2_cidr" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnet2_cidr
  availability_zone = var.azs[1]
  map_public_ip_on_launch = true

  tags =  {
    Name = "${var.project_name}-public-2"
    Enviroment = var.environment

  }
}


resource "aws_subnet" "private_subnet_cidr" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr
  availability_zone = var.azs[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-1"
    Enviroment = var.environment
  }
  
}


resource "aws_eip" "nat_eip" {
  domain = "vpc"

}

#Create the NAT Gateway in one of my Public Subnets
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.public_subnet1_cidr.id

  tags = {
    Name = var.nat
    Enviroment = var.environment
  }
   
  depends_on = [ aws_internet_gateway.igw_name ]
} 


resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route  {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  
  tags = {
    Name = "${var.project_name}-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_association" {
  subnet_id = aws_subnet.private_subnet_cidr.id
  route_table_id = aws_route_table.private_rt.id
  
} 

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route  {
    cidr_block = "0.0.0.0/0"
    gateway_id  = aws_internet_gateway.igw_name.id
  }
  
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet1_cidr.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc2" {
  subnet_id      = aws_subnet.public_subnet2_cidr.id
  route_table_id = aws_route_table.public_rt.id
}




resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_security_group" "instance_sg" {
  name        = "${var.project_name}-ec2-sg"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP from ALB only
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

 

  # Allow all outbound (for updates via NAT)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

resource "aws_lb_target_group" "alb_tg" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}_tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "alb_lt" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}


resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb_sg.id]

  subnets = [
    aws_subnet.public_subnet1_cidr.id,
    aws_subnet.public_subnet2_cidr.id
  ]

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project_name}-alb"
    Enviroment = var.environment
  }
}

  

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_role.name
  
}

resource "aws_instance" "instance" {
  ami = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  subnet_id = aws_subnet.private_subnet_cidr.id
  vpc_security_group_ids = [
    aws_security_group.instance_sg.id
  ]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd.x86_64
    systemctl start httpd.service
    systemctl enable httpd.service
    echo "Hello World from Terraform" > /var/www/html/index.html
  EOF


  tags = {
  Name = "${var.project_name}-prviate-instance"
  Enviroment = var.environment
  }

}
  
  resource "aws_lb_target_group_attachment" "test_attachment" {
  target_group_arn = aws_lb_target_group.alb_tg.arn
  target_id        = aws_instance.instance.id
  port             = 80 # Optional: specifies the port for this specific target

  depends_on = [ aws_instance.instance ]
}

