data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "ec2_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


data "aws_ami" "al2_latest" {
  most_recent = true
  owners      = ["self", "amazon"]
  filter {
    name   = "name"
    values = ["*amzn2*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}


data "aws_iam_policy" "managed_policy" {
  name = "AdministratorAccess"
}

resource "aws_iam_role" "ec2_role" {
  name                = "ec2_role"
  assume_role_policy  = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Action": "sts:AssumeRole",
			"Principal": {
				"Service": "ec2.amazonaws.com"
			},
			"Effect": "Allow"
		}
	]
}	
EOF
  managed_policy_arns = [data.aws_iam_policy.managed_policy.arn]
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name

}


resource "aws_key_pair" "ec2_key" {
  key_name   = "cloud9_key"
  public_key = file("~/.ssh/id_rsa.pub")

}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "ec2_sg"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.al2_latest.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  key_name               = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = data.aws_subnets.ec2_subnets.ids[0]
  user_data              = file("${path.module}/userdata.yaml")
}
