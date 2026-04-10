import json
import boto3
import os
import sys

S3_BUCKET = os.environ.get("S3_BUCKET", "go-s3-bucket-test")
S3_KEY = os.environ.get("S3_KEY", "ansible-outputs.json")
AWS_REGION = os.environ.get("AWS_REGION", "ap-south-1")

ANSIBLE_CONNECTION = "community.aws.aws_ssm"

def download_from_s3(bucket, key, dest, region):
    s3 = boto3.client("s3", region_name=region)
    s3.download_file(bucket, key, dest)

download_from_s3(S3_BUCKET, S3_KEY, "outputs.json", AWS_REGION)

with open("outputs.json") as f:
    data = json.load(f)

with open("inventory/hosts", "w") as f:
    f.write("[dbservers]\n")

    def write_instance(name, inst):
        f.write(
            f"{name} "
            f"ansible_host={inst['id']} "
            f"ansible_connection={ANSIBLE_CONNECTION} "
            f"ansible_aws_ssm_region={AWS_REGION} "
            f"ansible_aws_ssm_timeout=120\n"
        )

    for name, inst in data["primary_instances"]["value"].items():
        write_instance(name, inst)

    for name, inst in data["standby_instances"]["value"].items():
        write_instance(name, inst)