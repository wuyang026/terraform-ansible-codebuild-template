terraform {
  backend "s3" {
    bucket = "go-s3-bucket-test"
    key    = "terraform/ec2/terraform.tfstate"
    region = "ap-south-1"
  }
}