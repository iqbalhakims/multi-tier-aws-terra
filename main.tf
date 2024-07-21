# Define the provider
provider "aws" {
  region = "ap-southeast-1"
}

# Create the VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Main VPC"
  }
}

# Create the Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Internet Gateway"
  }
}

# Create the public subnets
resource "aws_subnet" "public_subnets" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

# Create the private subnets
resource "aws_subnet" "private_subnets" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 2}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

# Create the public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public_subnet_association" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create the NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    Name = "NAT Gateway"
  }
}

# Create the Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {
  vpc = true
  tags = {
    Name = "NAT Gateway EIP"
  }
}

# Create the private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "Private Route Table"
  }
}

# Associate private subnets with the private route table
resource "aws_route_table_association" "private_subnet_association" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private.id
}

# Create the security group for public subnets
resource "aws_security_group" "public_sg" {
  name        = "Public Security Group"
  description = "Allow inbound traffic on ports 22, 80, and 443"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Public Security Group"
  }
}

# Create the security group for private subnets
resource "aws_security_group" "private_sg" {
  name        = "Private Security Group"
  description = "Allow inbound traffic on ports 22, 80, 443, and 3306"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Private Security Group"
  }
}

# Get the latest Ubuntu 20.04 AMI
data "aws_ami" "ubuntu_20_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create the EC2 instances in public subnets
resource "aws_instance" "public_instances" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu_20_04.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.public_sg.id]

  tags = {
    Name = "Public Instance ${count.index + 1}"
  }
}

# Create the EC2 instances in private subnets
resource "aws_instance" "private_instances" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu_20_04.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tags = {
    Name = "Private Instance ${count.index + 1}"
  }
}

# Create a security group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "RDS Security Group"
  description = "Allow inbound traffic on port 3306 from private subnets"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.private_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS Security Group"
  }
}

# Create a subnet group for RDS
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id

  tags = {
    Name = "RDS Subnet Group"
  }
}

# Create the RDS instances in private subnets
resource "aws_db_instance" "rds_instances" {
  count                = 2
  identifier           = "mydb-${count.index + 1}"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  username             = "admin"
  password             = "YourStrongPasswordHere123!" # Change this to a secure password
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "RDS Instance ${count.index + 1}"
  }
}

# Create an Application Load Balancer
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public_subnets[*].id

  enable_deletion_protection = false

  tags = {
    Name = "Web ALB"
  }
}

# Create a security group for the ALB
resource "aws_security_group" "alb_sg" {
  name        = "ALB Security Group"
  description = "Allow inbound traffic on ports 80 and 443"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "ALB Security Group"
  }
}

# Create a target group for the ALB
resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    matcher             = "200"
  }
}

# Attach the public EC2 instances to the target group
resource "aws_lb_target_group_attachment" "web_tg_attachment" {
  count            = length(aws_instance.public_instances)
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.public_instances[count.index].id
  port             = 80
}

# Create an ACM certificate
resource "aws_acm_certificate" "cert" {
  domain_name       = "yourdomain.com"  # Replace with your domain
  validation_method = "DNS"

  tags = {
    Name = "Web ACM Certificate"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create a listener for HTTPS traffic
resource "aws_lb_listener" "front_end_https" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Create a listener for HTTP traffic (optional, for redirecting to HTTPS)
resource "aws_lb_listener" "front_end_http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Output the RDS endpoint addresses
output "rds_endpoints" {
  value = aws_db_instance.rds_instances[*].endpoint
}

# Output the ALB DNS name
output "alb_dns_name" {
  value = aws_lb.web_alb.dns_name
}