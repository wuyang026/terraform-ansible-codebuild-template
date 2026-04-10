import json
import boto3
import os
import sys

# =========================
# S3 設定
# =========================
S3_BUCKET = os.environ.get("S3_BUCKET", "go-s3-bucket-test")
S3_KEY = os.environ.get("S3_KEY", "ansible-outputs.json")
AWS_REGION = os.environ.get("AWS_REGION", "ap-south-1")

# =========================
# SSM / Ansible 設定（关键修复）
# =========================
ANSIBLE_CONNECTION = "community.aws.aws_ssm"
SSM_TIMEOUT = os.environ.get("SSM_TIMEOUT", "60")

def download_from_s3(bucket, key, dest, region):
    s3 = boto3.client("s3", region_name=region)
    try:
        s3.download_file(bucket, key, dest)
    except Exception as e:
        print(f"[ERROR] S3 ダウンロード失敗: {e}", file=sys.stderr)
        sys.exit(1)

# =========================
# 下载 Terraform output
# =========================
download_from_s3(S3_BUCKET, S3_KEY, "outputs.json", AWS_REGION)

with open("outputs.json") as f:
    data = json.load(f)

# =========================
# 写 inventory
# =========================
with open("inventory/hosts", "w") as f:
    f.write("[dbservers]\n")

    # primary instances
    for name, inst in data["primary_instances"]["value"].items():
        f.write(
            f"{name} "
            f"ansible_host={inst['id']} "
            f"ansible_connection={ANSIBLE_CONNECTION} "
            f"ansible_aws_ssm_region={AWS_REGION} "
            f"ansible_aws_ssm_bucket_name={S3_BUCKET} "
            f"ansible_aws_ssm_timeout={SSM_TIMEOUT}\n"
        )

    # standby instances
    for name, inst in data["standby_instances"]["value"].items():
        f.write(
            f"{name} "
            f"ansible_host={inst['id']} "
            f"ansible_connection={ANSIBLE_CONNECTION} "
            f"ansible_aws_ssm_region={AWS_REGION} "
            f"ansible_aws_ssm_bucket_name={S3_BUCKET} "
            f"ansible_aws_ssm_timeout={SSM_TIMEOUT}\n"
        )