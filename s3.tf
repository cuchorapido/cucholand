module "s3" {
  source = "terraform-aws-modules/s3-bucket/aws"

  create_bucket = local.using_existing_bucket ? false : true

  bucket = local.bucket
  #acl    = "private"

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