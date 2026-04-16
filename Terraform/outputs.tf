output "vpc_id" {
  value = aws_vpc.main.id
}

output "aws_dns" {
  value = aws_lb.main.dns_name
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "asg_desired_capacity" {
  value = aws_autoscaling_group.main.desired_capacity
}

output "aws_s3_bucket" {
  value = random_id.main.hex
}

output "aws-db-endpoint-aahe-manze-host-che-url-aahe" {
  value = aws_db_instance.main.endpoint
}