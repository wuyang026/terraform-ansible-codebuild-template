import json
import boto3
import os
import sys

# S3 設定
S3_BUCKET = os.environ.get("S3_BUCKET", "go-s3-bucket-test")
S3_KEY = os.environ.get("S3_KEY", "ansible-outputs.json")
AWS_REGION = os.environ.get("AWS_REGION", "ap-south-1")

def download_from_s3(bucket, key, dest, region):
    s3 = boto3.client('s3', region_name=region)
    try:
        s3.download_file(bucket, key, dest)
    except Exception as e:
        print(f"[ERROR] S3 から {key} のダウンロード失敗: {e}", file=sys.stderr)
        sys.exit(1)

# S3 から outputs.json を取得
download_from_s3(S3_BUCKET, S3_KEY, 'outputs.json', AWS_REGION)

with open("outputs.json") as f:
    data = json.load(f)

with open("inventory/hosts", "w") as f:
    f.write("[dbservers]\n")

    for name, inst in data["primary_instances"]["value"].items():
        f.write(f"{name} ansible_host={inst['id']} ansible_connection=aws_ssm\n")

    for name, inst in data["standby_instances"]["value"].items():
        f.write(f"{name} ansible_host={inst['id']} ansible_connection=aws_ssm\n")