variable "region" {
  description = "AWS リージョン"
  type        = string
  default     = "ap-south-1"
}

variable "ami_id" {
  description = "インスタンスのAMI ID"
  type        = string
  default     = "ami-01c68ee746ed2863d"
}

variable "instance_type" {
  description = "インスタンスタイプ"
  type        = string
  default     = "t3.micro"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = "vpc-0af4b08fb5339474e"
}

variable "subnet_1a_id" {
  description = "サブネット1a ID"
  type        = string
  default     = "subnet-01d8246ffc30e931a"
}

variable "subnet_1b_id" {
  description = "サブネット1b ID"
  type        = string
  default     = "subnet-073b3a850e74ba2d4"
}

variable "key_name" {
  description = "SSHキーペア名"
  type        = string
  default     = "my-key-pair"
}

variable "db_port" {
  description = "DBポート"
  type        = number
  default     = 3306
}

variable "primary_count" {
  description = "プライマリDBサーバーの数"
  type        = number
  default     = 9
}

variable "standby_count" {
  description = "スタンバイDBサーバーの数"
  type        = number
  default     = 9
}