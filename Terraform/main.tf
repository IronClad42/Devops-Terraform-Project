terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      # version = "6.39.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.aws_vpc_cidr_block
  tags = merge(local.common_tag, {
    Name = var.aws_vpc
  })
}

resource "aws_subnet" "subnet" {
  for_each = local.subnets

  vpc_id     = aws_vpc.main.id
  cidr_block = each.value.cidr_block

  availability_zone = (
    each.key == "public_subnet_1" ? "eu-north-1a" :
    each.key == "public_subnet_2" ? "eu-north-1b" :
    each.key == "private_subnet_3" ? "eu-north-1a" :
    each.key == "private_subnet_4" ? "eu-north-1b" :
    null
  )

  map_public_ip_on_launch = each.value.type == "public" ? true : false

  tags = merge(local.common_tag, {
    Name = "${each.key}-subnet"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tag, {
    Name = "devops-project-Internet-Gateway"
  })
}

resource "aws_eip" "nat" {
  for_each = {
    for key, subnet in local.subnets :
    key => subnet if subnet.type == "public"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {

  for_each = {
    for key, subnet in local.subnets :
    key => subnet if subnet.type == "public"
  }

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.subnet[each.key].id

  tags = merge(local.common_tag, {
    Name = "${each.key}-nat-gateway"
  })
}

# resource "aws_nat_gateway" "main" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = aws_subnet.subnet["public_subnet_1"].id
#   tags = {
#     Name = "devops-project-Nat-Gatway"
#   }
# }

resource "aws_route_table" "main" {
  for_each = local.subnets

  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = [1]

    content {
      cidr_block = "0.0.0.0/0"

      gateway_id = each.value.type == "public" ? aws_internet_gateway.main.id : null
      nat_gateway_id = each.value.type == "private" ? (
        each.key == "private_subnet_3" ? aws_nat_gateway.main["public_subnet_1"].id :
        each.key == "private_subnet_4" ? aws_nat_gateway.main["public_subnet_2"].id : null
      ) : null
    }
  }
  tags = merge(local.common_tag, {
    Name = "${each.key}-route-table"
  })
}

resource "aws_route_table_association" "main" {
  for_each = local.subnets

  subnet_id      = aws_subnet.subnet[each.key].id
  route_table_id = aws_route_table.main[each.key].id
}

resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["13.49.78.243/32"] # YOUR_IP
  } # SSH

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } # HTTP

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } # Jenkins

  ingress {
    from_port   = 1000
    to_port     = 1000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } # Node Js

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tag, {
    Name = "Devops-Projects-SG"
  })
}

resource "aws_security_group" "db_sg" {

  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.main.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tag, {
    Name = "Devops-Projects-DB-SG"
  })
}

resource "aws_instance" "main" {
  ami                         = "ami-077d1b9f9a1902bbc"
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.main.id]
  subnet_id                   = aws_subnet.subnet["public_subnet_1"].id
  associate_public_ip_address = true
  key_name                    = "linux"
  depends_on                  = [aws_security_group.main]

  user_data = <<-EOf
                  #!/bin/bash
                  sudo yum update -y
                  sudo yum install docker -y
                  sudo yum install git -y
                  sudo yum install nginx -y
                  sudo yum install nodejs -y
                  sudo yum install mysql-server -y
                  sudo yum install java-17-amazon-corretto -y
                  sudo wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins.io/redhat-stable/jenkins.repo
                  sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
                  sudo yum install jenkins -y
                  
                  sudo systemctl start docker
                  sudo systemctl enable docker
                  # sudo systemctl status docker
                  sudo systemctl start nginx
                  sudo systemctl enable nginx
                  # sudo systemctl status nginx
                  sudo systemctl start jenkins
                  sudo systemctl enable jenkins
                  # sudo systemctl status jenkins
                EOf


  lifecycle {
    create_before_destroy = true
    # prevent_destroy       = true
    replace_triggered_by = [aws_security_group.main]

    precondition {
      condition     = aws_security_group.main.id != ""
      error_message = "Security Group Id must not be blank"
    }

    postcondition {
      condition     = self.public_ip != ""
      error_message = "Public IP is not present."
    }
  }
  tags = merge(local.common_tag, {
    Name = "My-Devops-Projects"
  })
}

# LAUNCH TEMPLATE

resource "aws_launch_template" "main" {
  image_id      = "ami-077d1b9f9a1902bbc"
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.main.id]
  key_name               = "linux"

  user_data = base64encode(<<-EOF
                          #!/bin/bash
                          sudo yum update -y
                          sudo yum install docker -y
                          sudo yum install git -y
                          sudo yum install nginx -y
                          sudo yum install nodejs -y
                          sudo yum install mysql-server -y
                          sudo yum install java-17-amazon-corretto -y
                          sudo wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins.io/redhat-stable/jenkins.repo
                          sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
                          sudo yum install jenkins -y
                          
                          sudo systemctl start docker
                          sudo systemctl enable docker
                          # sudo systemctl status docker
                          sudo systemctl start nginx
                          sudo systemctl enable nginx
                          # sudo systemctl status nginx
                          sudo systemctl start jenkins
                          sudo systemctl enable jenkins
                          # sudo systemctl status jenkins
                      EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tag, {
      Name = "Devops-Project-Launch-Template"
    })
  }
}

# TARGET GROUP

resource "aws_lb_target_group" "main" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path     = "/"
    port     = "traffic-port"
    protocol = "HTTP"
  }

  tags = merge(local.common_tag, {
    Name = "Devops-Project-TARGET-GROUP"
  })
}

# Load Balancer

resource "aws_lb" "main" {
  load_balancer_type = "application"
  # subnets = [
  #   aws_subnet.subnet["public_subnet_1"].id
  # ]
  subnets = [
    aws_subnet.subnet["public_subnet_1"].id,
    aws_subnet.subnet["public_subnet_2"].id
  ]
  security_groups = [aws_security_group.main.id]

  tags = merge(local.common_tag, {
    Name = "Devops-Project-Load-Balancer"
  })
}

# listener

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_autoscaling_group" "main" {
  desired_capacity = 2
  max_size         = 4
  min_size         = 1

  vpc_zone_identifier = [
    aws_subnet.subnet["private_subnet_3"].id,
    aws_subnet.subnet["private_subnet_4"].id
  ]

  # vpc_zone_identifier = [
  #   aws_subnet.subnet["private_subnet_1"].id
  # ]

  launch_template {
    id      = aws_launch_template.main.id
    version = aws_launch_template.main.latest_version
  }

  target_group_arns = [aws_lb_target_group.main.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "Devops-ASG-Instance"
    propagate_at_launch = true
  }

}

resource "aws_autoscaling_policy" "main" {
  name                   = "cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_db_subnet_group" "main" {
  name = "my-db-subnet-group"

  subnet_ids = [
    aws_subnet.subnet["private_subnet_3"].id,
    aws_subnet.subnet["private_subnet_4"].id
  ]

  tags = merge(local.common_tag, {
    Name = "DB-Subnet-Group"
  })
}

resource "aws_db_instance" "main" {

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  db_name  = var.db_name
  username = var.db_user
  password = var.db_pass

  allocated_storage = 20
  storage_type      = "gp2"

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  depends_on = [aws_db_subnet_group.main]

  publicly_accessible = false
  skip_final_snapshot = true

  backup_retention_period = 7
  multi_az                = false

  tags = merge(local.common_tag, {
    Name = "My-RDS-Devops-Project"
  })
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "my-eks"
  cluster_version = "1.29"

  vpc_id = aws_vpc.main.id

  subnet_ids = [
    aws_subnet.subnet["private_subnet_3"].id,
    aws_subnet.subnet["private_subnet_4"].id
  ]

  cluster_endpoint_public_access = true
  enable_irsa                    = true

  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      instance_types = ["t3.micro"]

    }
  }

  tags = merge(local.common_tag, {
    Environment = "dev"
    Project     = "DevOps"
    Name        = "My-Devops-Project-EKS"
  })
}

resource "random_id" "main" {
  byte_length = 8
}

resource "aws_s3_bucket" "main" {
  bucket = "devops-project-${random_id.main.hex}"
}

resource "aws_s3_object" "main" {
  bucket = aws_s3_bucket.main.bucket
  source = "./terraform.tfstate"
  key    = "terraform.tfstate"
}

resource "aws_sns_topic" "main" {
  name = "Devops-Alert-Topic"
}

resource "aws_sns_topic_subscription" "main" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "email"
  endpoint  = "krishnabhujbal176@gmail.com"
}

resource "aws_cloudwatch_metric_alarm" "main" {
  alarm_name          = "cpu-utilization-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    InstanceId = aws_instance.main.id
  }

  alarm_actions = [aws_sns_topic.main.arn]

  tags = {
    Name = "Devops-Project-Alarm"
  }
}

# resource "aws_route53_record" "domain" {
#   zone_id = "REAL_ZONE_ID"

#   name = "yourdomain.com"
#   type = "A"


#   alias {
#     name                   = aws_cloudfront_distribution.cdn.domain_name
#     zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
#     evaluate_target_health = false
#   }
# }

# resource "aws_cloudfront_distribution" "cdn" {

#   enabled = true

#   origin {
#     domain_name = aws_lb.main.dns_name
#     origin_id   = "albOrigin"

#     custom_origin_config {
#       http_port              = 80
#       https_port             = 443
#       origin_protocol_policy = "http-only"
#       origin_ssl_protocols   = ["TLSv1.2"]
#     }
#   }

#   default_cache_behavior {
#     target_origin_id = "albOrigin"

#     viewer_protocol_policy = "redirect-to-https"

#     allowed_methods = ["GET", "HEAD"]
#     cached_methods  = ["GET", "HEAD"]

#     forwarded_values {
#       query_string = false

#       cookies {
#         forward = "none"
#       }
#     }
#   }

#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }

#   viewer_certificate {
#     cloudfront_default_certificate = true
#   }
# }
