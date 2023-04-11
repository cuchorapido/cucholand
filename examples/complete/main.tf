// Create a server using all defaults

provider "aws" {
  region = "us-east-2"
}

module "minecraft" {
  source = "../../"

  name                     = "cucholand"
  namespace                = "cuchorapido"
  environment              = "prod"
  bucket_object_versioning = true
  instance_type            = "t2.xlarge"

  mc_port        = 25565
  mc_root        = "/home/mc"
  mc_version     = "1.18.2"
  mc_backup_freq = 30

  java_ms_mem = "4G"
  java_mx_mem = "8G"


  tags = { By = "lxhxr" }
}
