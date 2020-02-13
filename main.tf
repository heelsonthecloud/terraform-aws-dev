provider "aws" {
  profile = "default"
  region = "us-east-2"
}
resource "aws_vpc" "heeled_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_subnet" "heeled_subnet" {
  vpc_id     = "${aws_vpc.heeled_vpc.id}"
  cidr_block = "10.0.1.0/24"
  depends_on = ["aws_internet_gateway.internet_gateway"]

}

resource "aws_security_group" "allow_tcp" {
  name        = "allow_tcp"
  description = "Allow TCP inbound traffic"
  vpc_id      = "${aws_vpc.heeled_vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "heeled_instance" {
  ami = "${var.ami_id}"
  instance_type = "t2.micro"
  key_name      = "${aws_key_pair.ssh-user.key_name}"
  security_groups = ["${aws_security_group.allow_tcp.id}"]
  subnet_id = "${aws_subnet.heeled_subnet.id}"



}
resource "aws_eip" "lb" {
  instance = "${aws_instance.heeled_instance.id}"
  vpc      = true
}
resource "aws_key_pair" "ssh-user" {
  key_name   = "deployer-key"
  public_key = "${file("./keys/id_rsa.pub")}"
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.heeled_vpc.id}"
}

resource "aws_route_table" "route_table" {
  vpc_id = "${aws_vpc.heeled_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }
}

resource "aws_route_table_association" "route_table_assoc" {
  subnet_id      = aws_subnet.heeled_subnet.id
  route_table_id = aws_route_table.route_table.id
}

