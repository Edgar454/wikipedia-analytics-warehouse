import boto3
import json
import time

LOG_GROUP = "/dbt/metrics"
LOG_STREAM = "dbt-runner"
SECRET_NAME = "wikipedia-analysis-gcp-service-account"
REGION = "eu-west-1"

def get_secret():
    client = boto3.client("secretsmanager", region_name=REGION)
    response = client.get_secret_value(SecretId=SECRET_NAME)
    return json.loads(response["SecretString"])

def get_cloudwatch_client():
    return boto3.client("logs")


def ensure_log_group_and_stream(client):
    try:
        client.create_log_group(logGroupName=LOG_GROUP)
    except client.exceptions.ResourceAlreadyExistsException:
        pass

    try:
        client.create_log_stream(
            logGroupName=LOG_GROUP,
            logStreamName=LOG_STREAM
        )
    except client.exceptions.ResourceAlreadyExistsException:
        pass


def send_logs(client, rows):
    sequence_token = None

    # get existing stream token if exists
    streams = client.describe_log_streams(
        logGroupName=LOG_GROUP,
        logStreamNamePrefix=LOG_STREAM
    )

    if streams["logStreams"]:
        sequence_token = streams["logStreams"][0].get("uploadSequenceToken")

    events = []

    for r in rows:
        events.append({
            "timestamp": int(time.time() * 1000),
            "message": json.dumps(r)
        })

    kwargs = {
        "logGroupName": LOG_GROUP,
        "logStreamName": LOG_STREAM,
        "logEvents": events,
    }

    if sequence_token:
        kwargs["sequenceToken"] = sequence_token

    client.put_log_events(**kwargs)