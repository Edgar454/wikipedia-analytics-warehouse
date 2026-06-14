from aws_utils import get_secret, get_cloudwatch_client, ensure_log_group_and_stream, send_logs
from bigquery_utils import get_bq_client, run_metrics_query

def main():
    secret = get_secret()
    client = get_bq_client(secret)
    rows = run_metrics_query(
        client,
        project_id=secret["project_id"],
        user_email=secret["client_email"]
    )

    print(f"Retrieved {len(rows)} rows")
    cw = get_cloudwatch_client()
    ensure_log_group_and_stream(cw)
    send_logs(cw, rows)

    print("Sent metrics to CloudWatch Logs")

if __name__ == "__main__":
    main()