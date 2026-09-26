variable "aws_region" {
  description = "AWS region for AWS Academy Learner Lab"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used for naming all resources"
  type        = string
  default     = "lab4dse"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "db_name" {
  type    = string
  default = "lab4db"
}

variable "db_username" {
  type    = string
  default = "lab4admin"
}

variable "db_password" {
  description = "RDS master password. Provide via terraform.tfvars (gitignored) or TF_VAR_db_password env var."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "redis_ttl_seconds" {
  type    = number
  default = 60
}

variable "lab_role_name" {
  description = "Name of the pre-existing IAM role provided by AWS Academy Learner Lab"
  type        = string
  default     = "LabRole"
}

