// Default network
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

data "aws_caller_identity" "aws" {}

// Find latest Ubuntu AMI, use as default if no AMI specified
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

// Script to configure the server - this is where most of the magic occurs!
data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")

  vars = {
    mc_root        = var.mc_root
    mc_bucket      = local.bucket
    mc_backup_freq = var.mc_backup_freq
    mc_version     = var.mc_version
    mc_type        = var.mc_type   
    java_mx_mem    = var.java_mx_mem
    java_ms_mem    = var.java_ms_mem
  }
}
