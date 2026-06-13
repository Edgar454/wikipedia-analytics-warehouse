variable "instance_type" {
  default = "r6i.xlarge"
}

variable "windows_ami" {
  description = "Windows Server 2022 AMI"
}

variable "key_name" {}