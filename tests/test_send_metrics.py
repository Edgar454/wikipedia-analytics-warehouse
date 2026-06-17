import pytest
from unittest.mock import Mock
from telemetry.aws_utils import send_metrics


@pytest.fixture
def cw_client():
    return Mock()


@pytest.fixture
def base_row():
    return {
        "query": '/* {"node_id":"model.wikipedia.mart_semantic_attention_base"} */ SELECT 1',
        "gb_billed": 1.5,
        "duration_seconds": 42,
        "status": "SUCCESS",
        "creation_time": "2026-06-01T00:00:00Z"
    }


# ── skip conditions ──────────────────────────────────────────────────────────

@pytest.mark.parametrize("query", [
    None,
    "",
    "select 1",
    "create schema if not exists dbt_dev",
])
def test_ignores_non_dbt_queries(cw_client, query):
    rows = [{
        "query": query,
        "gb_billed": 1.5,
        "duration_seconds": 10,
        "status": "SUCCESS",
        "creation_time": "2026-06-01T00:00:00Z"
    }]
    send_metrics(cw_client, rows)
    cw_client.put_metric_data.assert_not_called()


def test_ignores_empty_row_list(cw_client):
    send_metrics(cw_client, [])
    cw_client.put_metric_data.assert_not_called()


# ── happy path ───────────────────────────────────────────────────────────────

def test_publishes_three_base_metrics_on_success(cw_client, base_row):
    send_metrics(cw_client, [base_row])

    metric_data = cw_client.put_metric_data.call_args.kwargs["MetricData"]
    assert set(m["MetricName"] for m in metric_data) == {
        "GBScanned", "DurationSeconds", "QueryCount"
    }
    assert len(metric_data) == 3


def test_publishes_four_metrics_on_failure(cw_client, base_row):
    base_row["status"] = "FAILURE"
    send_metrics(cw_client, [base_row])

    metric_data = cw_client.put_metric_data.call_args.kwargs["MetricData"]
    assert "FailedQueries" in [m["MetricName"] for m in metric_data]
    assert len(metric_data) == 4


def test_correct_namespace(cw_client, base_row):
    send_metrics(cw_client, [base_row])
    assert cw_client.put_metric_data.call_args.kwargs["Namespace"] == "WikipediaAnalysis"


def test_correct_dimensions(cw_client, base_row):
    send_metrics(cw_client, [base_row])
    metric_data = cw_client.put_metric_data.call_args.kwargs["MetricData"]
    dimensions = {d["Name"]: d["Value"] for d in metric_data[0]["Dimensions"]}

    assert dimensions["Asset"] == "mart_semantic_attention_base"
    assert dimensions["NodeType"] == "model"
    assert dimensions["Status"] == "SUCCESS"


def test_correct_metric_values(cw_client, base_row):
    send_metrics(cw_client, [base_row])
    metric_data = cw_client.put_metric_data.call_args.kwargs["MetricData"]
    by_name = {m["MetricName"]: m for m in metric_data}

    assert by_name["GBScanned"]["Value"] == 1.5
    assert by_name["GBScanned"]["Unit"] == "Gigabytes"
    assert by_name["DurationSeconds"]["Value"] == 42
    assert by_name["DurationSeconds"]["Unit"] == "Seconds"
    assert by_name["QueryCount"]["Value"] == 1
    assert by_name["QueryCount"]["Unit"] == "Count"


# ── batching ─────────────────────────────────────────────────────────────────

def test_batches_over_1000_metrics(cw_client, base_row):
    rows = [base_row.copy() for _ in range(334)]
    send_metrics(cw_client, rows)
    assert cw_client.put_metric_data.call_count == 2


def test_multiple_rows_all_published(cw_client, base_row):
    rows = [base_row.copy() for _ in range(3)]
    send_metrics(cw_client, rows)
    metric_data = cw_client.put_metric_data.call_args.kwargs["MetricData"]
    assert len(metric_data) == 9


# ── mixed rows ───────────────────────────────────────────────────────────────

def test_skips_invalid_rows_publishes_valid(cw_client, base_row):
    rows = [
        {
            "query": "select 1",
            "gb_billed": 0,
            "duration_seconds": 0,
            "status": "SUCCESS",
            "creation_time": "2026-06-01T00:00:00Z"
        },
        base_row,
    ]
    send_metrics(cw_client, rows)
    cw_client.put_metric_data.assert_called_once()
    metric_data = cw_client.put_metric_data.call_args.kwargs["MetricData"]
    assert len(metric_data) == 3