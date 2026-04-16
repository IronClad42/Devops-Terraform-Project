variable "region" {
  default = "eu-north-1"
}

variable "aws_vpc" {
  default = "devops-project-VPC"
}

variable "aws_vpc_cidr_block" {
  type = string
}

variable "db_name" {
  sensitive = true
}

variable "db_user" {
  sensitive = true
}

variable "db_pass" {
  sensitive = true
}