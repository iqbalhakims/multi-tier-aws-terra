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

# Output the ALB DNS name
output "alb_dns_name" {
  value = aws_lb.web_alb.dns_name
}

# ... (rest of the previous code remains the same)