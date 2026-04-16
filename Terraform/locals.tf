locals {

  project = "Devops-project"

  common_tag = {
    Project = local.project
  }

  subnets = {
    public_subnet_1 = {
      cidr_block = "10.0.1.0/24"
      type = "public"
    }
    public_subnet_2 = {
      cidr_block = "10.0.2.0/24"
      type = "public"
    }
    private_subnet_3 = {
      cidr_block = "10.0.3.0/24"
      type = "private"
    }
    private_subnet_4 = {
      cidr_block = "10.0.4.0/24"
      type = "private"
    }
  }
} 