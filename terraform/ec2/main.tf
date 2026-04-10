############################################
# IAMロール（SSM用）
############################################
resource "aws_iam_role" "ec2_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_role.name
}

############################################
# DB用 Security Group
############################################
resource "aws_security_group" "db_sg" {
  name_prefix = "db-sg-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DB-SG-SSM-ONLY"
  }
}

############################################
# SSM Endpoint専用SG（重要修正）
############################################
resource "aws_security_group" "ssm_endpoint_sg" {
  name   = "ssm-endpoint-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# VPC Endpoint（SSM）
############################################
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id]
  security_group_ids  = [aws_security_group.ssm_endpoint_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id]
  security_group_ids  = [aws_security_group.ssm_endpoint_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id]
  security_group_ids  = [aws_security_group.ssm_endpoint_sg.id]
  private_dns_enabled = true
}

############################################
# user_data（RHEL9 + SSM完全修正版）
############################################
locals {
  user_data = <<-EOF
#!/bin/bash
set -xe

LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "===== USER DATA START ====="

dnf install -y python3 curl unzip

python3 -m ensurepip || true
python3 -m pip install --upgrade pip || true
python3 -m pip install boto3 || true

echo "SSM Agent install..."

dnf install -y https://s3.${var.region}.amazonaws.com/amazon-ssm-${var.region}/latest/linux_amd64/amazon-ssm-agent.rpm

systemctl enable amazon-ssm-agent
systemctl restart amazon-ssm-agent

sleep 10

systemctl status amazon-ssm-agent || true

echo "===== USER DATA END ====="
EOF
}

############################################
# EC2 Primary
############################################
resource "aws_instance" "primary" {
  count         = var.primary_count
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id = element(
    [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id],
    count.index % 3
  )

  vpc_security_group_ids = [aws_security_group.db_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = local.user_data

  tags = {
    Name = "PrimaryDB-${count.index + 1}"
    Role = "primary"
  }
}

############################################
# EC2 Standby
############################################
resource "aws_instance" "standby" {
  count         = var.standby_count
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id = element(
    [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id],
    count.index % 3
  )

  vpc_security_group_ids = [aws_security_group.db_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = local.user_data

  tags = {
    Name = "StandbyDB-${count.index + 1}"
    Role = "standby"
  }
}