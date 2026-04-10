#!/usr/bin/env python3

import json

# Terraformの出力を読み込む
with open('outputs.json', 'r') as f:
    outputs = json.load(f)

# inventory/hosts を生成
with open('inventory/hosts', 'w') as f:
    f.write('[dbservers]\n')
    # プライマリDBサーバー
    for key, instance in outputs['primary_instances']['value'].items():
        f.write(f'{key} ansible_host={instance["id"]} ansible_connection=aws_ssm ansible_aws_ssm_region=ap-south-1\n')
    # スタンバイDBサーバー
    for key, instance in outputs['standby_instances']['value'].items():
        f.write(f'{key} ansible_host={instance["id"]} ansible_connection=aws_ssm ansible_aws_ssm_region=ap-south-1\n')
    f.write('\n[dbservers:vars]\n')
    f.write('ansible_python_interpreter=/usr/bin/python3\n')