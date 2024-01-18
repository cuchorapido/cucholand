// EC2 instance for the server - tune instance_type to fit your performance and budget requirements
module "ec2_minecraft" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-ec2-instance.git?ref=master"
  name   = "${var.name}-public"

  # instance
  key_name             = local.ssh_key_name
  ami                  = var.ami != "" ? var.ami : data.aws_ami.ubuntu.image_id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.mc.id
  user_data            = data.template_file.user_data.rendered

  # network
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [ aws_security_group.this.id ]
  associate_public_ip_address = var.associate_public_ip_address

  # spot
  create_spot_instance = true
  spot_price           = "0.60"
  spot_type            = "persistent"
  tags = module.label.tags
}

