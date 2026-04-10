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

############################################
# SSM用ポリシーのアタッチ
############################################
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

############################################
# EC2インスタンスプロファイル
############################################
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_role.name
}

############################################
# DB用セキュリティグループ
############################################
resource "aws_security_group" "db_sg" {
  name_prefix = "db-sg-"
  vpc_id      = var.vpc_id

  # DBポート許可（テスト用に全開）
  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # アウトバウンド全許可
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
# SSM VPCエンドポイント用セキュリティグループ
############################################
resource "aws_security_group" "ssm_endpoint_sg" {
  name   = "ssm-endpoint-sg"
  vpc_id = var.vpc_id

  # HTTPS通信許可
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # アウトバウンド全許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# SSM関連VPCエンドポイント（Interface型）
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
# S3 VPCエンドポイント（Gateway型）
############################################
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = data.aws_route_tables.main.ids
}

############################################
# EC2用 user_data（SSMインストール）
############################################
locals {
  user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

URL="https://s3.ap-south-1.amazonaws.com/amazon-ssm-ap-south-1/latest/linux_amd64/amazon-ssm-agent.rpm"
FILE="/tmp/amazon-ssm-agent.rpm"

echo "Downloading SSM agent..."
curl -fL --retry 3 --retry-delay 2 -o "$FILE" "$URL"

echo "Verifying file..."
test -s "$FILE"

echo "Installing RPM..."
rpm -Uvh "$FILE"

echo "Enabling service..."
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
EOF
}

############################################
# EC2（Primary）
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
  depends_on = [
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.ssm_messages,
    aws_vpc_endpoint.ec2_messages,
    aws_vpc_endpoint.s3
  ]
}

############################################
# EC2（Standby）
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
  depends_on = [
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.ssm_messages,
    aws_vpc_endpoint.ec2_messages,
    aws_vpc_endpoint.s3
  ]
}