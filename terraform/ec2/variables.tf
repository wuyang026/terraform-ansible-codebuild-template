variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "ami_id" {
  type    = string
  default = "ami-01c68ee746ed2863d"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "vpc_id" {
  type    = string
  default = "vpc-0af4b08fb5339474e"
}

variable "subnet_1a_id" {
  type    = string
  default = "subnet-01d8246ffc30e931a"
}

variable "subnet_1b_id" {
  type    = string
  default = "subnet-073b3a850e74ba2d4"
}

variable "key_name" {
  type    = string
  default = "my-key-pair"
}

variable "db_port" {
  type    = number
  default = 3306
}

variable "primary_count" {
  type    = number
  default = 1
}

variable "standby_count" {
  type    = number
  default = 1
}

variable "s3_bucket" {
  type    = string
  default = "go-s3-bucket-test"
}

# SSM VPC Endpointを作成するかどうかを制御
variable "create_ssm_endpoint" {
  type    = bool
  default = true
}