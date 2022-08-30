// Create a server using all defaults

provider "aws" {
  region = "us-east-2"
}

module "bungecord" {
  source = "../../"

  name                     = "bungecord"
  namespace                = "aelcraft"
  environment              = "prod"
  bucket_object_versioning = false
  instance_type            = "t2.large"

  mc_port        = 25605
  mc_root        = "/home/mc"
  mc_version     = "1.18.2"
  mc_backup_freq = 10

  java_ms_mem = "2G"
  java_mx_mem = "4G"


  tags = { By = "lxhxr" }
}

# module "lobby" {
#   source = "../../"

#   name                     = "lobby"
#   namespace                = "aelcraft"
#   environment              = "prod"
#   bucket_object_versioning = false
#   instance_type            = "t2.medium"

#   mc_port        = 25566
#   mc_root        = "/home/mc"
#   mc_version     = "1.18.2"
#   mc_backup_freq = 10

#   java_ms_mem = "2G"
#   java_mx_mem = "4G"


#   tags = { By = "lxhxr" }
# }
