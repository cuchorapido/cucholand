// S3 bucket for persisting minecraft
resource "random_string" "s3" {
  length  = 12
  special = false
  upper   = false
}

locals {
  bucket = length(var.bucket_name) > 0 ? var.bucket_name : "${module.label.id}-${random_string.s3.result}"
  ssh_key_name = length(var.key_name) > 0 ? var.key_name : aws_key_pair.ec2_ssh[0].key_name
  subnet_id = length(var.subnet_id) > 0 ? var.subnet_id : sort(data.aws_subnets.default.ids)[0]
  tf_tags = {
    Terraform = true,
    By        = data.aws_caller_identity.aws.arn
  }
  using_existing_bucket = signum(length(var.bucket_name)) == 1
  vpc_id    = length(var.vpc_id) > 0 ? var.vpc_id : data.aws_vpc.default.id
}