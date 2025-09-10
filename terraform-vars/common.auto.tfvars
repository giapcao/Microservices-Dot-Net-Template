# Common Infrastructure Variables
project_name = "vkev"
aws_region   = "us-east-1"
region       = "us-east-1"

# VPC Configuration
vpc_cidr               = "10.0.0.0/16"
public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidr    = "10.0.3.0/24"

# EC2 Configuration
instance_type         = "t2.micro"
associate_public_ip   = true

# ECS Global Settings
enable_auto_scaling      = false
enable_service_discovery = false
 