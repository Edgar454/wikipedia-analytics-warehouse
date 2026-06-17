import boto3
import json
import time
import uuid
import re   
from datetime import datetime, timezone


LOG_GROUP = "/dbt/metrics"
LOG_STREAM = "dbt-runner"
SECRET_NAME = "wikipedia-analysis-gcp-service-account"
REGION = "eu-west-1"

def get_secret():
    client = boto3.client("secretsmanager", region_name=REGION)
    response = client.get_secret_value(SecretId=SECRET_NAME)
    return json.loads(response["SecretString"])

def get_cloudwatch_logs_client():
    return boto3.client("logs")

def get_cloudwatch_metrics_client():
    return boto3.client("cloudwatch")


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

def extract_node_id(query):
    if not query:
        return None
    match = re.search(r"/\*\s*(\{.*?\})\s*\*/", query, re.DOTALL)
    if not match:
        return None
    try:
        metadata = json.loads(match.group(1))
        return metadata.get("node_id")
    except Exception:
        return None

def extract_asset_name(node_id):
    if not node_id:
        return None
    parts = node_id.split(".")
    if len(parts) < 3:
        return None
    return parts[-1][:255]

def send_logs(client, rows):
    if not rows:
        print("No rows to send")
        return

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
        r["creation_time"] = str(r["creation_time"])
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

def send_metrics(client, rows):

    if not rows:
        print("No metrics to publish")
        return

    metric_data = []

    run_id = datetime.now(timezone.utc).strftime("run-%Y%m%d-%H%M%S")

    global_dimensions = [
        {
            "Name": "RunId",
            "Value": run_id
        }
    ]

    valid_rows = []

    for row in rows:

        node_id = extract_node_id(row["query"])
        asset_name = extract_asset_name(node_id)

        if not node_id or not asset_name:
            continue

        valid_rows.append(row)

        query_dimensions = [
            {
                "Name": "Asset",
                "Value": asset_name
            },
            {
                "Name": "NodeType",
                "Value": node_id.split(".")[0]
            },
            {
                "Name": "Status",
                "Value": row["status"]
            }
        ]

        dimensions = global_dimensions + query_dimensions

        metric_data.extend([
            {
                "MetricName": "GBScanned",
                "Timestamp": row["creation_time"],
                "Value": row["gb_billed"],
                "Unit": "Gigabytes",
                "Dimensions": dimensions
            },
            {
                "MetricName": "DurationSeconds",
                "Timestamp": row["creation_time"],
                "Value": row["duration_seconds"],
                "Unit": "Seconds",
                "Dimensions": dimensions
            },
            {
                "MetricName": "QueryCount",
                "Timestamp": row["creation_time"],
                "Value": 1,
                "Unit": "Count",
                "Dimensions": dimensions
            }
        ])

        if row["status"] == "FAILURE":
            metric_data.append({
                "MetricName": "FailedQueries",
                "Timestamp": row["creation_time"],
                "Value": 1,
                "Unit": "Count",
                "Dimensions": dimensions
            })

    # publish query-level metrics

    for i in range(0, len(metric_data), 1000):
        client.put_metric_data(
            Namespace="WikipediaAnalysis",
            MetricData=metric_data[i:i + 1000]
        )

    has_failures = any(
        row["status"] == "FAILURE"
        for row in valid_rows
    )

    run_duration = sum(
        row["duration_seconds"]
        for row in valid_rows
    )

    client.put_metric_data(
        Namespace="WikipediaAnalysis",
        MetricData=[
            {
                "MetricName": "RunDurationSeconds",
                "Timestamp": datetime.now(timezone.utc),
                "Value": run_duration,
                "Unit": "Seconds",
                "Dimensions": global_dimensions
            },
            {
                "MetricName": "RunSuccess",
                "Timestamp": datetime.now(timezone.utc),
                "Value": 0 if has_failures else 1,
                "Unit": "Count",
                "Dimensions": global_dimensions
            },
            {
                "MetricName": "RunTotal",
                "Timestamp": datetime.now(timezone.utc),
                "Value": 1,
                "Unit": "Count",
                "Dimensions": global_dimensions
            }
        ]
    )