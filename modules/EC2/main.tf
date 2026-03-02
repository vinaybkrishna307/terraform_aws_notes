variable "name" {}
variable "ami" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "vpc_id" {}
variable "allowed_ingress_cidr" {
  type = list(string)
}


# ssm access only no ssh so port 22 is not opened
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.ec2_role.name
}



resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Production EC2 security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-lt"
  image_id      = var.ami
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  vpc_security_group_ids = [aws_security_group.this.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"  # IMDSv2 enforced without this attackers can steal IAM role creds with metadata
  }

  monitoring {
    enabled = true  # detailed monitoring
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  disable_api_termination = true

  user_data = base64encode(<<EOF
#!/bin/bash
yum update -y
EOF
  )
}

resource "aws_instance" "this" {
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  subnet_id = var.subnet_id

  tags = {
    Name = var.name
  }
}

/*

ADVANCED PROD LEVEL CHANGES
1)Add EBS KMS Custom Key
2)Restrict Outbound Traffic
3)Use VPC Endpoints for SSM
4)Add CloudWatch Agent via user_data
5)Enable GuardDuty + Inspector
*/




