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

  backend "s3" {
    bucket = "my-static-bucket-12233344445555556666667777777"
    key    = "terraform.tfstate"
    region = "eu-north-1"
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
  # for_each = {
  #   for key, subnet in local.subnets :
  #   key => subnet if subnet.type == "public"
  # }
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {

  # for_each = {
  #   for key, subnet in local.subnets :
  #   key => subnet if subnet.type == "public"
  # }

  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet["public_subnet_1"].id

  tags = merge(local.common_tag, {
    Name = "main-nat-gateway"
  })
}

# resource "aws_nat_gateway" "main" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = aws_subnet.subnet["public_subnet_1"].id
#   tags = {
#     Name = "devops-project-Nat-Gatway"
#   }
# }

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id

  }
  tags = merge(local.common_tag, {
    Name = "Public-route-table"
  })
}

resource "aws_route_table" "private" {

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tag, {
    Name = "private-route-table"
  })
}

resource "aws_route_table_association" "public_1" {

  subnet_id      = aws_subnet.subnet["public_subnet_1"].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {

  subnet_id      = aws_subnet.subnet["public_subnet_2"].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {

  subnet_id      = aws_subnet.subnet["private_subnet_3"].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.subnet["private_subnet_4"].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # YOUR_IP
    # cidr_blocks = ["13.49.246.145/32"] # YOUR_IP
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

resource "aws_security_group" "main_aws_load_balancer" {

  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tag, {
    Name = "Devops-Projects-aws-load_balancer-SG"
  })
}

resource "aws_security_group" "db_sg" {

  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    security_groups = [
      module.eks.cluster_security_group_id,
      aws_security_group.main.id
    ]
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

resource "aws_instance" "main_public_instances" {

  count = 2

  ami                    = "ami-077d1b9f9a1902bbc"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id = element([
    aws_subnet.subnet["public_subnet_1"].id,
    aws_subnet.subnet["public_subnet_2"].id
  ], count.index)
  associate_public_ip_address = true
  key_name                    = "linux"
  depends_on                  = [aws_security_group.main]

  user_data = <<-EOf
                  #!/bin/bash
                  sudo yum update -y
                  sudo dnf update -y
                  sudo yum install docker -y
                  sudo yum install git -y
                  sudo yum install nginx -y
                  sudo yum install nodejs -y
                  sudo yum install mariadb105-server -y

                  
                  sudo dnf install java-17-amazon-corretto -y
                  sudo dnf install java-21-amazon-corretto -y
                  sudo dnf install awscli -y

                  
                  sudo wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins.io/redhat-stable/jenkins.repo
                  sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
                  sudo dnf install jenkins -y
                  
                  sudo mkdir -p /var/jenkins_temp
                  sudo chmod 755 /var/jenkins_temp
                  
                  sudo mkdir -p /etc/systemd/system/jenkins.service.d/

                  cat <<EOF | sudo tee /etc/systemd/system/jenkins.service.d/override.conf
                  [Service]
                  Environment="JAVA_OPTS=-Djava.io.temdir=/var/jenkins_temp"
                  EOF

                  curl -LO \
                  "https://dl.k8s.io/release/$(curl -L -s \
                  https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

                  chmod +x kubectl

                  sudo mv kubectl /usr/local/bin/

                  sudo usermod -aG docker ec2-user
                  sudo usermod -aG docker jenkins
                  sudo chmod 666 /var/run/docker.sock
                  
                  aws eks update-kubeconfig \
                  --region eu-north-1 \
                  --name my-eks

                  sudo mkdir -p /var/lib/jenkins/.kube
                  sudo cp /root/.kube/config \ /var/lib/jenkins/.kube/config
                  sudo chown -R jenkins:jenkins \ /var/lib/jenkins/.kube
                  sudo chmod 755 /var/lib/jenkins/.kube
                  sudo chmod 644 \ /var/lib/jenkins/.kube/config

                  kubectl get nodes

                  sudo -u jenkins kubectl get nodes


                  sudo systemctl daemon-reload
                  sudo systemctl daemon-reexec
                  sudo systemctl enable docker nginx jenkins
                  sudo systemctl start docker nginx jenkins

                  sudo systemctl daemon-reload
                  sudo systemctl daemon-reexec
                  sudo systemctl restart docker
                  sudo systemctl restart jenkins    
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
    Name = "My-Devops-Projects-Public-Instance-${count.index + 1}"
  })
}

resource "aws_instance" "main_private_instances" {
  count         = 2
  ami           = "ami-077d1b9f9a1902bbc"
  instance_type = "t3.micro"

  subnet_id = element([
    aws_subnet.subnet["private_subnet_3"].id,
    aws_subnet.subnet["private_subnet_4"].id
  ], count.index)

  vpc_security_group_ids = [aws_security_group.main.id]

  associate_public_ip_address = false
  key_name                    = "linux"

  tags = merge(local.common_tag, {
    Name = "My-Devops-Projects-Private-Instance-${count.index + 1}"
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
                          sudo yum install mariadb105-server -y
                          sudo dnf update -y

                          sudo dnf install java-17-amazon-corretto -y
                          sudo dnf install java-21-amazon-corretto -y
                          sudo dnf install awscli -y

                          sudo wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins.io/redhat-stable/jenkins.repo
                          sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
                          sudo dnf install jenkins -y

                          sudo mkdir -p /var/jenkins_temp
                          sudo chmod 755 /var/jenkins_temp
                          sudo mkdir -p /etc/systemd/system/jenkins.service.d/

                          cat <<EOT | sudo tee /etc/systemd/system/jenkins.service.d/override.conf
                          [Service]
                          Environment="JAVA_OPTS=-Djava.io.tmpdir=/var/jenkins_temp"
                          EOT

                          curl -LO "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

                          chmod +x kubectl
                          sudo mv kubectl /usr/local/bin/

                          sudo usermod -aG docker ec2-user
                          sudo usermod -aG docker jenkins

                          aws eks update-kubeconfig \
                          --region eu-north-1 \
                          --name my-eks

                          sudo mkdir -p /var/lib/jenkins/.kube

                          sudo cp /root/.kube/config /var/lib/jenkins/.kube/config

                          sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube

                          sudo chmod 755 /var/lib/jenkins/.kube
                          sudo chmod 644 /var/lib/jenkins/.kube/config

                          kubectl get nodes

                          sudo -u jenkins kubectl get nodes

                          sudo systemctl daemon-reload
                          sudo systemctl daemon-reexec

                          sudo systemctl enable docker
                          sudo systemctl enable nginx
                          sudo systemctl enable jenkins

                          sudo systemctl start docker
                          sudo systemctl start nginx
                          sudo systemctl start jenkins

                          sudo systemctl restart docker
                          sudo systemctl restart jenkins
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
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = "30"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
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
  desired_capacity = 1
  min_size         = 1
  max_size         = 2

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
  cluster_version = "1.30"

  vpc_id = aws_vpc.main.id

  subnet_ids = [
    aws_subnet.subnet["private_subnet_3"].id,
    aws_subnet.subnet["private_subnet_4"].id
  ]

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  create_cloudwatch_log_group = false

  eks_managed_node_group_defaults = {
    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    default = {
      desired_size = 2
      min_size     = 1
      max_size     = 3

      instance_types = ["t3.medium"]
      ami_type       = "AL2_x86_64"
    }
  }

  tags = merge(local.common_tag, {
    Environment = "dev"
    Project     = "DevOps"
    Name        = "My-Devops-Project-EKS"
  })
}

# resource "aws_iam_user_policy_attachment" "eks_admin" {

#   user = "tf-user"
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"
# }

resource "aws_eks_access_entry" "tf_user_access" {

  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::084375574576:user/tf-user"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "tf_user_admin" {

  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::084375574576:user/tf-user"

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "random_id" "main" {
  byte_length = 8
}

# resource "aws_s3_bucket" "main" {
#   bucket = "devops-project-my-static-bucket-12233344445555556666667777777"
# }

# resource "aws_s3_object" "main" {
#   bucket = aws_s3_bucket.main.bucket
#   source = "./terraform.tfstate"
#   key    = "terraform.tfstate"
# }

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
  namespace           = "AWS/AutoScaling"
  period              = 60
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    InstanceId = aws_instance.main_public_instances[0].id
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
