// This module creates a single EC2 instance for running a Minecraft server

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

locals {
  vpc_id    = length(var.vpc_id) > 0 ? var.vpc_id : data.aws_vpc.default.id
  subnet_id = length(var.subnet_id) > 0 ? var.subnet_id : sort(data.aws_subnets.default.ids)[0]
  tf_tags = {
    Terraform = true,
    By        = data.aws_caller_identity.aws.arn
  }
}

// Keep labels, tags consistent
module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=master"

  namespace   = var.namespace
  stage       = var.environment
  name        = var.name
  delimiter   = "-"
  label_order = ["environment", "stage", "name", "attributes"]
  tags        = merge(var.tags, local.tf_tags)
}

// Amazon Linux2 AMI - can switch this to default by editing the EC2 resource below
data "aws_ami" "amazon-linux-2" {
  most_recent = true

  owners = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

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

// S3 bucket for persisting minecraft
resource "random_string" "s3" {
  length  = 12
  special = false
  upper   = false
}

#data "aws_s3_bucket" "selected" {
#  bucket = local.bucket
#}

locals {
  availability_zone = "${local.region}a"
  region            = "us-east-2"
  using_existing_bucket = signum(length(var.bucket_name)) == 1

  bucket = length(var.bucket_name) > 0 ? var.bucket_name : "${module.label.id}-${random_string.s3.result}"
}

module "s3" {
  source = "terraform-aws-modules/s3-bucket/aws"

  create_bucket = local.using_existing_bucket ? false : true

  bucket = local.bucket
  acl    = "private"

  force_destroy = var.bucket_force_destroy

  versioning = {
    enabled = var.bucket_object_versioning
  }

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = module.label.tags
}

// IAM role for S3 access
resource "aws_iam_role" "allow_s3" {
  name   = "${module.label.id}-allow-ec2-to-s3"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "mc" {
  name = "${module.label.id}-instance-profile"
  role = aws_iam_role.allow_s3.name
}

resource "aws_iam_role_policy" "mc_allow_ec2_to_s3" {
  name   = "${module.label.id}-allow-ec2-to-s3"
  role   = aws_iam_role.allow_s3.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::${local.bucket}",
        "arn:aws:s3:::cuchorapido"

      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::${local.bucket}/*",
        "arn:aws:s3:::cuchorapido/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeAddress",
       "ec2:AssociateAddress",
       "ec2:DescribeInstance",
       "ec2:AllocateAddress"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

# // Script to configure the server - this is where most of the magic occurs!
# data "template_file" "user_data" {
#   template = file("${path.module}/user_data_bungecord.sh")

#   vars = {
#     mc_root        = var.mc_root
#     mc_bucket      = local.bucket
#     mc_backup_freq = var.mc_backup_freq
#     mc_version     = var.mc_version
#     mc_type        = var.mc_type   
#     java_mx_mem    = var.java_mx_mem
#     java_ms_mem    = var.java_ms_mem
#   }
# }

// Security group for our instance - allows SSH and minecraft 
resource "aws_security_group" "this" {
  name        = "${var.name}-ec2"
  description = "Allow SSH and TCP ${var.mc_port}"
  vpc_id      = local.vpc_id

  ingress {
    description      = "ssh-tcp"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [ var.allowed_cidrs ]
  }
  ingress {
    description      = "minecraft-server"
    from_port        = var.mc_port
    to_port          = var.mc_port
    protocol         = "tcp"
    cidr_blocks      = [ var.allowed_cidrs ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = module.label.tags
}


// Create EC2 ssh key pair
resource "tls_private_key" "ec2_ssh" {
  count = length(var.key_name) > 0 ? 0 : 1

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_ssh" {
  count = length(var.key_name) > 0 ? 0 : 1

  key_name   = "${var.name}-ec2-ssh-key"
  public_key = tls_private_key.ec2_ssh[0].public_key_openssh
}

locals {
  _ssh_key_name = length(var.key_name) > 0 ? var.key_name : aws_key_pair.ec2_ssh[0].key_name
}

# // EC2 instance for the server - tune instance_type to fit your performance and budget requirements
# module "ec2_minecraft" {
#   source = "git::https://github.com/terraform-aws-modules/terraform-aws-ec2-instance.git?ref=master"
#   name   = "${var.name}-public"

#   # instance
#   key_name             = local._ssh_key_name
#   ami                  = var.ami != "" ? var.ami : data.aws_ami.ubuntu.image_id
#   instance_type        = var.instance_type
#   iam_instance_profile = aws_iam_instance_profile.mc.id
#   user_data            = data.template_file.user_data.rendered

#   # network
#   subnet_id                   = local.subnet_id
#   vpc_security_group_ids      = [ aws_security_group.this.id ]
#   associate_public_ip_address = var.associate_public_ip_address

#   tags = module.label.tags
# }

resource "aws_launch_template" "bugecord" {
  name = "${var.name}-bugecord"
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 8
    }
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.mc.id
  }
  image_id =  var.ami != "" ? var.ami : data.aws_ami.ubuntu.image_id
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = "1.00"
      spot_instance_type = "one-time"
    }
  }
  instance_type = var.instance_type
  key_name = local._ssh_key_name
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination = true
    device_index = 0
    security_groups = [ aws_security_group.this.id ]
    subnet_id = local.subnet_id
  }
  tags = module.label.tags
  user_data = base64encode(join("\n", [
    templatefile("${path.module}/user_data_bungecord.tpl", {
      tpl_eip            = aws_eip.this.public_ip
      tpl_eip_id         = aws_eip.this.id
      tpl_region         = local.region
      tpl_java_mx_mem    = var.java_mx_mem
      tpl_java_ms_mem    = var.java_ms_mem
    }
    )
  ]))
      # tpl_mc_root        = var.mc_root
      # tpl_mc_bucket      = local.bucket
      # tpl_mc_backup_freq = var.mc_backup_freq
      # tpl_mc_version     = var.mc_version
      # tpl_mc_type        = var.mc_type     
  //filebase64("${path.module}/user_data_bungecord.sh")
}

resource "aws_autoscaling_group" "bugecord" {
  #availability_zones = [local.availability_zone]
  default_cooldown = 10
  desired_capacity   = 0
  health_check_type  = "EC2"
  health_check_grace_period = 30 
  max_size           = 1
  min_size           = 0
  name  = "${var.name}-bugecord-asg"
  instance_refresh {
    preferences {
      min_healthy_percentage = 0
    } 
    strategy = "Rolling"
    triggers = ["launch_template"]
  }
  launch_template {
    id      = aws_launch_template.bugecord.id
    version = "$Latest"
  }
  vpc_zone_identifier = [ local.subnet_id ]
  #tag  = tolist(module.label.tags)
}


# # ssd
# resource "aws_volume_attachment" "this" {
#   device_name = "/dev/sdf"
#   volume_id   = "vol-05ff074874ff7b859"
#   instance_id = module.ec2_minecraft.id
# }

# # static ip 
resource "aws_eip" "this" {
  vpc  = true
  tags = module.label.tags
}