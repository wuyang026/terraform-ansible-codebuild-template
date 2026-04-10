############################################
# EC2用 IAM ロール（SSM接続用）
############################################
resource "aws_iam_role" "ec2_role" {
  name = "ec2-ssm-role"

  # EC2がこのロールを引き受けるための信頼ポリシー
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

# SSM接続に必須のポリシー
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3アクセス（Ansible + SSM連携で使用）
resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# EC2にアタッチするインスタンスプロファイル
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_role.name
}

############################################
# セキュリティグループ（SSM利用前提）
############################################
resource "aws_security_group" "db_sg" {
  name_prefix = "db-sg-"
  vpc_id      = var.vpc_id

  # SSM通信（HTTPS）のみ許可
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DBポート（必要に応じて制限することを推奨）
  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # アウトバウンド通信はすべて許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DB-SecurityGroup"
  }
}

############################################
# EC2 初期化スクリプト（非常に重要）
############################################
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -xe

    # ログ出力先
    LOG_FILE="/var/log/user-data.log"
    exec > >(tee -a $LOG_FILE) 2>&1

    echo "===== START user_data ====="

    # Python3 インストール
    yum install -y python3

    # pip 初期化
    python3 -m ensurepip || true

    # pip アップグレード
    python3 -m pip install --upgrade pip

    # boto3 インストール（Ansible SSMに必須）
    python3 -m pip install boto3

    # 動作確認
    python3 --version
    python3 -m pip list | grep boto3

    # SSM Agent の起動確認
    systemctl enable amazon-ssm-agent
    systemctl restart amazon-ssm-agent

    echo "===== END user_data ====="
  EOF
}

############################################
# Primary ノード
############################################
resource "aws_instance" "primary" {
  count                  = var.primary_count
  ami                    = var.ami_id
  instance_type          = var.instance_type

  # AZ分散配置
  subnet_id              = element([var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id], count.index % 3)

  vpc_security_group_ids = [aws_security_group.db_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # 初期設定スクリプト
  user_data = local.user_data

  # 追加EBSボリューム
  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = 10
    volume_type = "gp2"
  }

  tags = {
    Name = "PrimaryDB-${count.index + 1}"
    Role = "primary"
  }
}

############################################
# Standby ノード
############################################
resource "aws_instance" "standby" {
  count                  = var.standby_count
  ami                    = var.ami_id
  instance_type          = var.instance_type

  subnet_id              = element([var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id], count.index % 3)

  vpc_security_group_ids = [aws_security_group.db_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = local.user_data

  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = 10
    volume_type = "gp2"
  }

  tags = {
    Name = "StandbyDB-${count.index + 1}"
    Role = "standby"
  }
}

############################################
# SSM用 VPCエンドポイント（プライベート接続）
############################################
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id]
  security_group_ids  = [aws_security_group.db_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id]
  security_group_ids  = [aws_security_group.db_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id]
  security_group_ids  = [aws_security_group.db_sg.id]
  private_dns_enabled = true
}