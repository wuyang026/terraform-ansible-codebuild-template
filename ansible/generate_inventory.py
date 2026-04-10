import json
import boto3
import os
import sys

S3_BUCKET = os.environ.get("S3_BUCKET", "go-s3-bucket-test")
S3_KEY = os.environ.get("S3_KEY", "ansible-outputs.json")
AWS_REGION = os.environ.get("AWS_REGION", "ap-south-1")

def download_from_s3(bucket, key, dest, region):
    s3 = boto3.client("s3", region_name=region)
    try:
        s3.download_file(bucket, key, dest)
    except Exception as exc:
        print(f"failed to download s3://{bucket}/{key}: {exc}", file=sys.stderr)
        sys.exit(1)

download_from_s3(S3_BUCKET, S3_KEY, "outputs.json", AWS_REGION)

try:
    with open("outputs.json") as f:
        data = json.load(f)
except Exception as exc:
    print(f"failed to read outputs.json: {exc}", file=sys.stderr)
    sys.exit(1)

if "primary_instances" not in data or "standby_instances" not in data:
    print("outputs.json is missing primary_instances or standby_instances", file=sys.stderr)
    sys.exit(1)

with open("inventory/hosts", "w") as f:
    f.write("[dbservers]\n")

    def write_instance(name, inst):
        f.write(f"{name} ansible_host={inst['id']}\n")

    for name, inst in data["primary_instances"]["value"].items():
        write_instance(name, inst)

    for name, inst in data["standby_instances"]["value"].items():
        write_instance(name, inst)

    f.write("\n[dbservers:vars]\n")
    f.write("ansible_connection=aws_ssm\n")
    f.write(f"ansible_aws_ssm_bucket_name={S3_BUCKET}\n")
    f.write(f"ansible_aws_ssm_region={AWS_REGION}\n")
    f.write("ansible_aws_ssm_timeout=120\n")
    f.write("ansible_aws_ssm_s3_addressing_style=virtual\n")
    f.write("ansible_python_interpreter=/usr/bin/python3\n")
    f.write("ansible_remote_tmp=/tmp/.ansible/tmp\n")