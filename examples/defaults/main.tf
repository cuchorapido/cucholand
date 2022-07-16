// Create a server using all defaults

provider "aws" {
  region  = "us-west-2"
}

module "minecraft" {
  source = "../../"
}
