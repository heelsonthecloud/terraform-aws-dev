variable "ami_name" {
  type = string
  default = "Amazon Linux AMIyes"
}
variable "ami_id" {
  type = string
  default = "ami-02ccb28830b645a41"
}
variable "ami_id_centos" {
  type = string
  default = "ami-00138b07206d4ceaf"
}

variable "vpc_id" {
  type = string
  default="heeled-vpc"
}

