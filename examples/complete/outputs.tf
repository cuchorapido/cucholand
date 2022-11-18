output "vpc_id" {
  value = module.minecraft.vpc_id
}

output "subnet_id" {
  value = module.minecraft.subnet_id
}

output "public_ip" {
  value = module.minecraft.public_ip
}

output "ssh_command_by_ip" {
  value = "ssh -i ..\\..\\ec2-private-key.pem -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@${module.minecraft.public_ip}"
}

output "ssh_command_by_hostname" {
  value = "ssh -i ..\\..\\ec2-private-key.pem -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@cucholand.lxhxr.com"
}

output "id" {
  value = module.minecraft.id
}

output "minecraft_server" {
  value = module.minecraft.minecraft_server
}

output "s3" {
  value = module.minecraft.s3
}

