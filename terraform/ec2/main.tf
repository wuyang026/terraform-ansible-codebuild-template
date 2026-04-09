provider "aws" {
  region = var.region
}

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

# DBサーバー用のセキュリティグループ
resource "aws_security_group" "db_sg" {
  name_prefix = "db-sg-"
  vpc_id      = var.vpc_id

  # SSHアクセス
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DBポートアクセス
  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # すべてのアウトバウンドトラフィック
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

# プライマリDBサーバー
resource "aws_instance" "primary" {
  count         = var.primary_count
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = count.index % 2 == 0 ? var.subnet_1a_id : var.subnet_1b_id
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

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

# スタンバイDBサーバー
resource "aws_instance" "standby" {
  count         = var.standby_count
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = count.index % 2 == 0 ? var.subnet_1a_id : var.subnet_1b_id
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

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