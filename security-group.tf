// Security group for our instance - allows SSH and minecraft 
resource "aws_security_group" "this" {
  name        = "${var.name}-ec2"
  description = "Allow SSH, ${var.mc_port}, http"
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

  ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [ var.allowed_cidrs ]
  }
  ingress {
    description      = "migracion"
    from_port        = 3000
    to_port          = 3000
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
