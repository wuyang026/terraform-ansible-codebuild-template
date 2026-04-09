# プライマリDBサーバーの出力
output "primary_instances" {
  description = "プライマリDBサーバーのインスタンス情報"
  value = {
    for idx, instance in aws_instance.primary : "primary-${idx + 1}" => {
      id          = instance.id
      name        = instance.tags["Name"]
      public_ip   = instance.public_ip
      private_ip  = instance.private_ip
      subnet_id   = instance.subnet_id
    }
  }
}

# スタンバイDBサーバーの出力
output "standby_instances" {
  description = "スタンバイDBサーバーのインスタンス情報"
  value = {
    for idx, instance in aws_instance.standby : "standby-${idx + 1}" => {
      id          = instance.id
      name        = instance.tags["Name"]
      public_ip   = instance.public_ip
      private_ip  = instance.private_ip
      subnet_id   = instance.subnet_id
    }
  }
}

# セキュリティグループID
output "db_security_group_id" {
  description = "DBセキュリティグループID"
  value       = aws_security_group.db_sg.id
}

# キーペア名
output "key_name" {
  description = "SSHキーペア名"
  value       = var.key_name
}