from aws_utils import ( get_secret, get_cloudwatch_logs_client,get_cloudwatch_metrics_client,
                        ensure_log_group_and_stream, send_logs , send_metrics )
from bigquery_utils import get_bq_client, run_metrics_query 

def main():
    secret = get_secret()
    client = get_bq_client(secret)
    rows = run_metrics_query(
        client,
        user_email=secret["client_email"]
    )

    print(f"Retrieved {len(rows)} rows")
    cw_logs = get_cloudwatch_logs_client()
    cw_metrics = get_cloudwatch_metrics_client()

    ensure_log_group_and_stream(cw_logs)
    send_logs(cw_logs, rows)
    send_metrics(cw_metrics , rows)

    print("Sent metrics to CloudWatch Logs")

if __name__ == "__main__":
    main()