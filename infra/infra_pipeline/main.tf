provider "aws" {
  region = "eu-west-1"
}

resource "aws_instance" "powerbi_vm" {
  ami           = var.windows_ami
  instance_type = var.instance_type

  key_name = var.key_name

  vpc_security_group_ids = [aws_security_group.rdp.id]

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  user_data = file("user_data.ps1")

  tags = {
    Name = "powerbi-dev-vm"
  }
}