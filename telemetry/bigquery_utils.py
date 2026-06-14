from google.cloud import bigquery
from google.oauth2 import service_account

def get_bq_client(service_account_info):
    credentials = service_account.Credentials.from_service_account_info(
        service_account_info,
        scopes=["https://www.googleapis.com/auth/bigquery"]
    )

    return bigquery.Client(
        credentials=credentials,
        project=service_account_info["project_id"]
    )


def test_query(client):
    query = "SELECT 1 as test"

    job = client.query(query)
    result = job.result()

    for row in result:
        print("BigQuery test result:", row.test)

def run_metrics_query(client, project_id, user_email):
    query = """
    SELECT
      creation_time,
      user_email,
      job_id,
      TIMESTAMP_DIFF(end_time, start_time, SECOND) AS total_time_seconds,

      CASE
        WHEN error_result.reason IS NULL THEN 'SUCCESS'
        ELSE 'FAILURE'
      END AS job_status,

      error_result.message AS error_message,

      ROUND(total_bytes_billed / POW(1024, 3), 2) AS gb_billed,

      query

    FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT

    WHERE user_email = @user_email
      AND creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)

    ORDER BY creation_time DESC
    """

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("user_email", "STRING", user_email)
        ]
    )

    query_job = client.query(query, job_config=job_config)

    results = query_job.result()

    rows = []

    for row in results:
        rows.append({
            "creation_time": str(row.creation_time),
            "job_id": row.job_id,
            "duration_seconds": row.total_time_seconds,
            "status": row.job_status,
            "error_message": row.error_message,
            "gb_billed": float(row.gb_billed) if row.gb_billed else 0.0,
            "query": row.query
        })

    return rows