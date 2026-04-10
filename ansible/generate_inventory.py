import json

with open("outputs.json") as f:
    data = json.load(f)

with open("inventory/hosts", "w") as f:
    f.write("[dbservers]\n")

    for name, inst in data["primary_instances"]["value"].items():
        f.write(f"{name} ansible_host={inst['id']} ansible_connection=aws_ssm\n")

    for name, inst in data["standby_instances"]["value"].items():
        f.write(f"{name} ansible_host={inst['id']} ansible_connection=aws_ssm\n")