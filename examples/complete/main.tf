// Create a server using all defaults

provider "aws" {
  region  = "us-east-2"
}

module "minecraft" {
  source = "../../"

  name        = "cucholand"
  namespace   = "cuchorapido"
  environment = "prod"

  #key_name = "cuchorapido-cucholand"

  mc_port        = 30000
  mc_root        = "/home/mc"
  mc_version     = "latest"
  mc_backup_freq = 10

  java_ms_mem = "1G"
  java_mx_mem = "1G"


  tags = { By = "lxhxr" }
}
