terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "devops-tfstate-hu1"
    key            = "alb-nginx/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "alb-vpc"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "alb-igw"
  }
}

# --- Public Subnets ---
resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "alb-public-subnet1"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "alb-public-subnet2"
  }
}

resource "aws_subnet" "public_subnet3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[2]
  availability_zone       = var.availability_zones[2]
  map_public_ip_on_launch = true
  tags = {
    Name = "alb-public-subnet3"
  }
}

# --- Route Table ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "alb-public-rt"
  }
}

resource "aws_route_table_association" "public_associate1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_associate2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_associate3" {
  subnet_id      = aws_subnet.public_subnet3.id
  route_table_id = aws_route_table.public.id
}

# --- Security Group ---
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow inbound traffic on ports 80, 443, and 22"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH traffic"
    from_port   = 22
    to_port     = 22
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
    Name = "alb-sg"
  }
}

# --- EC2 Instances ---
resource "aws_instance" "web_server_1" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet1.id
  vpc_security_group_ids      = [aws_security_group.alb_sg.id]
  associate_public_ip_address = true

  user_data = <<EOF
#!/bin/bash
sudo dnf update -y
sudo dnf install -y nginx.x86_64
sudo systemctl start nginx
sudo systemctl enable nginx
echo "<h1>${var.page_titles[0]}</h1>" | sudo tee -a /usr/share/nginx/html/index.html
sudo chown -R nginx:nginx /usr/share/nginx/html
sudo chmod -R 755 /usr/share/nginx/html
EOF

  tags = {
    Name = "WebServer-sub-1"
  }
}

resource "aws_instance" "web_server_2" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet2.id
  vpc_security_group_ids      = [aws_security_group.alb_sg.id]
  associate_public_ip_address = true

  user_data = <<EOF
#!/bin/bash
sudo dnf update -y
sudo dnf install -y nginx.x86_64
sudo systemctl start nginx
sudo systemctl enable nginx
mkdir /usr/share/nginx/html/images
echo "<h1>${var.page_titles[1]}</h1>" | sudo tee -a /usr/share/nginx/html/images/index.html
sudo chown -R nginx:nginx /usr/share/nginx/html/images
sudo chmod -R 755 /usr/share/nginx/html/images
EOF

  tags = {
    Name = "WebServer-sub-2"
  }
}

resource "aws_instance" "web_server_3" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet3.id
  vpc_security_group_ids      = [aws_security_group.alb_sg.id]
  associate_public_ip_address = true

  user_data = <<EOF
#!/bin/bash
sudo dnf update -y
sudo dnf install -y nginx.x86_64
sudo systemctl start nginx
sudo systemctl enable nginx
mkdir /usr/share/nginx/html/register
echo "<h1>${var.page_titles[2]}</h1>" | sudo tee -a /usr/share/nginx/html/register/index.html
sudo chown -R nginx:nginx /usr/share/nginx/html/register
sudo chmod -R 755 /usr/share/nginx/html/register
EOF

  tags = {
    Name = "WebServer-sub-3"
  }
}

# --- ALB ---
resource "aws_lb" "alb" {
  internal                  = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
  subnets                    = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id, aws_subnet.public_subnet3.id]
  enable_deletion_protection = false

  tags = {
    Name = "path-alb"
  }
}

# --- Target Groups ---
resource "aws_lb_target_group" "alb_tg_home" {
  name        = "alb-tg-home"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    timeout             = 5
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = {
    Name = "alb-tg-home"
  }
}

resource "aws_lb_target_group" "alb_tg_images" {
  name        = "alb-tg-images"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/images/"
    timeout             = 5
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = {
    Name = "alb-tg-images"
  }
}

resource "aws_lb_target_group" "alb_tg_register" {
  name        = "alb-tg-register"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/register/"
    timeout             = 5
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = {
    Name = "alb-tg-register"
  }
}

# --- ALB Listener ---
resource "aws_lb_listener" "alb_http_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg_home.arn
  }
}

# --- ALB Listener Rules ---
resource "aws_lb_listener_rule" "alb_rule_images" {
  listener_arn = aws_lb_listener.alb_http_listener.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg_images.arn
  }

  condition {
    path_pattern {
      values = ["/images/*"]
    }
  }
}

resource "aws_lb_listener_rule" "alb_rule_register" {
  listener_arn = aws_lb_listener.alb_http_listener.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg_register.arn
  }

  condition {
    path_pattern {
      values = ["/register/*"]
    }
  }
}

# --- Target Group Attachments ---
resource "aws_lb_target_group_attachment" "alb_tg_attach_home" {
  target_group_arn = aws_lb_target_group.alb_tg_home.arn
  target_id        = aws_instance.web_server_1.id
}

resource "aws_lb_target_group_attachment" "alb_tg_attach_images" {
  target_group_arn = aws_lb_target_group.alb_tg_images.arn
  target_id        = aws_instance.web_server_2.id
}

resource "aws_lb_target_group_attachment" "alb_tg_attach_register" {
  target_group_arn = aws_lb_target_group.alb_tg_register.arn
  target_id        = aws_instance.web_server_3.id
}
