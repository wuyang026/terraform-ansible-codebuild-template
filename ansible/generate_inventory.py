#!/usr/bin/env python3

import json
import sys
import boto3
import os

# ==========================================
# 環境変数取得
# ==========================================
S3_BUCKET = os.environ.get("S3_BUCKET", "go-s3-bucket-test")
S3_KEY = os.environ.get("S3_KEY", "terraform-outputs.json")
AWS_REGION = os.environ.get("AWS_REGION", "ap-south-1")

# ==========================================
# S3からTerraform出力を取得
# ==========================================
def download_from_s3(bucket, key, dest, region):
    s3 = boto3.client('s3', region_name=region)
    try:
        s3.download_file(bucket, key, dest)
    except Exception as e:
        print(f"[ERROR] S3ダウンロード失敗: {e}", file=sys.stderr)
        sys.exit(1)

download_from_s3(S3_BUCKET, S3_KEY, 'outputs.json', AWS_REGION)

# ==========================================
# JSON読み込み
# ==========================================
try:
    with open('outputs.json', 'r') as f:
        outputs = json.load(f)
except Exception as e:
    print(f"[ERROR] JSON読み込み失敗: {e}", file=sys.stderr)
    sys.exit(1)

# ==========================================
# inventory生成
# ==========================================
with open('inventory/hosts', 'w') as f:
    f.write('[dbservers]\n')

    # Primaryノード
    for key, instance in outputs['primary_instances']['value'].items():
        f.write(f'{key} ansible_host={instance["id"]} ansible_connection=aws_ssm ansible_aws_ssm_region={AWS_REGION} ansible_python_interpreter=/usr/bin/python3\n')

    # Standbyノード
    for key, instance in outputs['standby_instances']['value'].items():
        f.write(f'{key} ansible_host={instance["id"]} ansible_connection=aws_ssm ansible_aws_ssm_region={AWS_REGION} ansible_python_interpreter=/usr/bin/python3\n')

    # 共通変数
    f.write('\n[dbservers:vars]\n')
    f.write(f'ansible_aws_ssm_region={AWS_REGION}\n')
    f.write(f'ansible_aws_ssm_s3_bucket={S3_BUCKET.strip()}\n')
    f.write('ansible_python_interpreter=/usr/bin/python3\n')