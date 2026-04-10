#!/usr/bin/env python3



import json
import sys

S3_BUCKET = "go-s3-bucket-test"  # デフォルト
outputs = None
try:
    with open('outputs.json', 'r') as f:
        outputs = json.load(f)
        if 's3_bucket' in outputs and 'value' in outputs['s3_bucket']:
            S3_BUCKET = str(outputs['s3_bucket']['value'])
except Exception as e:
    print(f"[ERROR] outputs.json 読み込み失敗: {e}", file=sys.stderr)
    sys.exit(1)

if not outputs or 'primary_instances' not in outputs or 'standby_instances' not in outputs:
    print("[ERROR] outputs.json に primary_instances または standby_instances がありません。", file=sys.stderr)
    sys.exit(1)

# inventory/hosts を生成
with open('inventory/hosts', 'w') as f:
    f.write('[dbservers]\n')
    # プライマリDBサーバー
    for key, instance in outputs['primary_instances']['value'].items():
        f.write(f'{key} ansible_host={instance["id"]} ansible_connection=aws_ssm ansible_aws_ssm_region=ap-south-1 ansible_python_interpreter=/usr/bin/python3.9\n')
    # スタンバイDBサーバー
    for key, instance in outputs['standby_instances']['value'].items():
        f.write(f'{key} ansible_host={instance["id"]} ansible_connection=aws_ssm ansible_aws_ssm_region=ap-south-1 ansible_python_interpreter=/usr/bin/python3.9\n')
    f.write('\n[dbservers:vars]\n')
    f.write('ansible_aws_ssm_region=ap-south-1\n')
    f.write(f'ansible_aws_ssm_s3_bucket={S3_BUCKET.strip()}\n')
    f.write('ansible_python_interpreter=/usr/bin/python3.9\n')