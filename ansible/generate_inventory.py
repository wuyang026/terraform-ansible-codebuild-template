#!/usr/bin/env python3

import json

S3_BUCKET = "go-s3-bucket-test"  # デフォルト

# outputs.json から S3 バケット名を取得（なければデフォルト）
try:
    with open('outputs.json', 'r') as f:
        outputs = json.load(f)
        if 's3_bucket' in outputs and 'value' in outputs['s3_bucket']:
            S3_BUCKET = str(outputs['s3_bucket']['value'])
except Exception:
    pass


# Terraformの出力を読み込む（上で取得済み）

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
    f.write(f'ansible_aws_ssm_s3_bucket={S3_BUCKET}\n')
    f.write('ansible_python_interpreter=/usr/bin/python3.9\n')