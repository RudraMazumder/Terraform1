provider "aws" {
  region     = "us-east-1"
  shared_credentials_file="C:\\Users\\RUMAZUMD\\.awscredentials"
}

variable "subnet_prefix" {
  description = "CIDR range of the subnet"
}

resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "rudra_dev"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "rudra_dev"
  }
}

resource "aws_route_table" "dev_routetable" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "rudra_dev"
  }
}

resource "aws_subnet" "dev_subnet" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = var.subnet_prefix
  availability_zone = "us-east-1a"

  tags = {
    Name = "rudra_dev"
  }
}

resource "aws_route_table_association" "dev_subnet_association" {
  subnet_id      = aws_subnet.dev_subnet.id
  route_table_id = aws_route_table.dev_routetable.id
}


resource "aws_security_group" "allow_webtraffic" {
  name        = "allow_web"
  description = "Allow Web Traffic"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}


resource "aws_network_interface" "rudra_dev_nic" {
  subnet_id       = aws_subnet.dev_subnet.id
  private_ips     = ["10.1.100.50"]
  security_groups = [aws_security_group.allow_webtraffic.id]

}

resource "aws_eip" "rudra_dev_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.rudra_dev_nic.id
  associate_with_private_ip = "10.1.100.50"
  depends_on = [
    "aws_internet_gateway.gw"
  ]
}

resource "aws_instance" "tf_rudra" {
  ami               = "ami-083654bd07b5da81d"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "tf-test"
  network_interface {
    network_interface_id = aws_network_interface.rudra_dev_nic.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo echo "you very first webservice" > /var/www/html/index.html
              EOF

  tags = {
    Name = "rudra_dev"
  }
}
