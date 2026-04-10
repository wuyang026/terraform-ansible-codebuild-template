############################################
# IAMロール（SSM接続用）
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

############################################
# SSMフルマネージドアクセス権限
############################################
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

############################################
# S3アクセス権限（必要に応じて利用）
############################################
resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

############################################
# EC2インスタンスプロファイル
############################################
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_role.name
}

############################################
# セキュリティグループ（SSM専用構成）
############################################
resource "aws_security_group" "db_sg" {
  name_prefix = "db-sg-"
  vpc_id      = var.vpc_id

  ##########################################
  # DBポート（必要な場合のみ公開）
  ##########################################
  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ##########################################
  # 注意：
  # SSH(22)は完全に無効化（SSMのみ使用）
  ##########################################

  ##########################################
  # アウトバウンド通信（全許可）
  ##########################################
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
# ユーザーデータ（初期設定）
############################################
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -xe

    ########################################
    # ログ出力設定
    ########################################
    LOG_FILE="/var/log/user-data.log"
    exec > >(tee -a $LOG_FILE) 2>&1

    echo "===== ユーザーデータ開始 ====="

    ########################################
    # 基本ツールインストール
    ########################################
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y python3 curl unzip
    else
      yum install -y python3 curl unzip
    fi

    ########################################
    # pip設定 & boto3インストール
    ########################################
    python3 -m ensurepip || true
    python3 -m pip install --upgrade pip
    python3 -m pip install boto3

    ########################################
    # SSM Agent インストール（重要）
    ########################################
    echo "SSM Agent インストール開始..."

    yum install -y https://s3.${var.region}.amazonaws.com/amazon-ssm-${var.region}/latest/linux_amd64/amazon-ssm-agent.rpm

    systemctl enable amazon-ssm-agent
    systemctl restart amazon-ssm-agent

    systemctl status amazon-ssm-agent || true

    echo "===== ユーザーデータ終了 ====="
  EOF
}

############################################
# Primary EC2
############################################
resource "aws_instance" "primary" {
  count                  = var.primary_count
  ami                    = var.ami_id
  instance_type          = var.instance_type

  # AZ分散配置
  subnet_id = element(
    [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id],
    count.index % 3
  )

  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # IAMロール付与（SSM用）
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = local.user_data

  ##########################################
  # EBS追加ディスク
  ##########################################
  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = 10
    volume_type = "gp3"
  }

  tags = {
    Name = "PrimaryDB-${count.index + 1}"
    Role = "primary"
  }
}

############################################
# Standby EC2
############################################
resource "aws_instance" "standby" {
  count                  = var.standby_count
  ami                    = var.ami_id
  instance_type          = var.instance_type

  subnet_id = element(
    [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id],
    count.index % 3
  )

  vpc_security_group_ids = [aws_security_group.db_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = local.user_data

  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = 10
    volume_type = "gp3"
  }

  tags = {
    Name = "StandbyDB-${count.index + 1}"
    Role = "standby"
  }
}

############################################
# SSM VPCエンドポイント（必須）
############################################

# SSM本体
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id]
  security_group_ids  = [aws_security_group.db_sg.id]
  private_dns_enabled = true
}

# SSMメッセージ通信
resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id]
  security_group_ids  = [aws_security_group.db_sg.id]
  private_dns_enabled = true
}

# EC2メッセージ通信
resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_1a_id, var.subnet_1b_id, var.subnet_1c_id]
  security_group_ids  = [aws_security_group.db_sg.id]
  private_dns_enabled = true
}