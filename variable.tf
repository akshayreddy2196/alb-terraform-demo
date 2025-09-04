variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-00ca32bbc84273381"
}

variable "instance_type" {
  description = "Instance type for EC2 instances"
  type        = string
  default     = "t2.micro"
}

variable "page_titles" {
  description = "Page titles for the Nginx servers"
  type        = list(string)
  default     = ["Home - Page!", "Images!", "Register!"]
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "availability_zones" {
  description = "List of AZs to deploy subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
