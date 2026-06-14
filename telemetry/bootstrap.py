import json
import os
import boto3
import sys

SECRET_NAME = os.environ["GCP_SECRET_NAME"]

client = boto3.client("secretsmanager")

response = client.get_secret_value(
    SecretId=SECRET_NAME
)

secret = json.loads(response["SecretString"])

key_path = "/tmp/gcp-key.json"

with open(key_path, "w") as f:
    json.dump(secret, f)

print(f"GCP credentials written to {key_path}", file=sys.stderr)

print(f"export GOOGLE_APPLICATION_CREDENTIALS={key_path}")
print(f"export GCP_PROJECT_ID={secret['project_id']}")