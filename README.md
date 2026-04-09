# Terraform Ansible CodeBuild Template

このプロジェクトは、Terraformを使ってAWSインフラをデプロイし、Ansibleで設定し、AWS CodeBuildでCI/CDを行うテンプレートです。

## 構造

- `terraform/ec2/`: EC2モジュール（DBサーバー）
  - `main.tf`: リソース定義
  - `variables.tf`: 変数定義
  - `outputs.tf`: 出力定義
- `ansible/`: Ansibleプレイブックとインベントリ
- `scripts/`: ユーティリティスクリプト
- `buildspec.yml`: AWS CodeBuildのビルド仕様

## DBサーバー構成

- プライマリDBサーバー: 9台 (異なるAZに分散)
- スタンバイDBサーバー: 9台 (異なるAZに分散)
- 各サーバーはt3.micro、AMI: ami-01c68ee746ed2863d
- リージョン: ap-south-1
- VPC: vpc-0af4b08fb5339474e
- サブネット: subnet-01d8246ffc30e931a (1a), subnet-073b3a850e74ba2d4 (1b)
- セキュリティグループ: SSH (22) とDBポート (3306) を開放
- EBS: 10GB追加

## 使用方法

1. Terraformの初期化: `cd terraform/ec2 && terraform init`
2. 計画: `terraform plan`
3. 適用: `terraform apply`
4. Ansible実行: `ansible-playbook ../ansible/playbooks/main.yml`

## CI/CD

`buildspec/` フォルダに2つのビルド仕様があります：
- `buildspec/terraform.yml`: Terraformのデプロイ専用
- `buildspec/ansible.yml`: Ansibleの構成専用

AWS CodeBuildで別々のプロジェクトを作成して使用します。

## 拡張

- `terraform/eks/` フォルダでEKS関連のコードを追加可能。