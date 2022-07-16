// Create a server using all defaults

provider "aws" {
  region  = "us-east-2"
}

module "minecraft" {
  source = "../../"

  name        = "cucholand"
  namespace   = "cuchorapido"
  environment = "prod"

  # vpc_id    = "vpc-01b84c68"
  # subnet_id = "subnet-58c83531"

  # bucket_name = "cuchorapid-cucholand-1"

  # ami      = "ami-0d6621c01e8c2de2c"
  key_name = "cuchorapido-cucholand"

  mc_port        = 30000
  mc_root        = "/home/mc"
  mc_version     = "1.18.2"
  mc_backup_freq = 10

  java_ms_mem = "1G"
  java_mx_mem = "1G"


  tags = { By = "lxhxr" }
}
