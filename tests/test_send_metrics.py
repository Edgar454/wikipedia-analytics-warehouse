import pytest
from datetime import datetime, timezone
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
        "creation_time": datetime(2026, 6, 1, 0, 0, 0, tzinfo=timezone.utc)
    }


def get_all_metric_data(cw_client):
    metrics = []

    for call in cw_client.put_metric_data.call_args_list:
        metrics.extend(call.kwargs["MetricData"])

    return metrics


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
        "creation_time": datetime(
            2026, 6, 1, 0, 0, 0,
            tzinfo=timezone.utc
        )
    }]

    send_metrics(cw_client, rows)

    cw_client.put_metric_data.assert_not_called()


def test_null_query_does_not_raise(cw_client):

    rows = [{
        "query": None,
        "gb_billed": 0,
        "duration_seconds": 0,
        "status": "SUCCESS",
        "creation_time": datetime.now(timezone.utc)
    }]

    send_metrics(cw_client, rows)

    cw_client.put_metric_data.assert_not_called()


def test_ignores_empty_row_list(cw_client):

    send_metrics(cw_client, [])

    cw_client.put_metric_data.assert_not_called()


# ── happy path ───────────────────────────────────────────────────────────────

def test_publishes_base_metrics_on_success(cw_client, base_row):

    send_metrics(cw_client, [base_row])

    metric_data = get_all_metric_data(cw_client)

    assert {
        m["MetricName"]
        for m in metric_data
    } == {
        "GBScanned",
        "DurationSeconds",
        "QueryCount",
        "RunDurationSeconds",
        "RunSuccess",
        "RunTotal",
    }


def test_publishes_failed_query_metric(cw_client, base_row):

    base_row["status"] = "FAILURE"

    send_metrics(cw_client, [base_row])

    metric_data = get_all_metric_data(cw_client)

    assert "FailedQueries" in {
        m["MetricName"]
        for m in metric_data
    }


def test_correct_namespace(cw_client, base_row):

    send_metrics(cw_client, [base_row])

    for call in cw_client.put_metric_data.call_args_list:
        assert call.kwargs["Namespace"] == "WikipediaAnalysis"


def test_correct_dimensions(cw_client, base_row):

    send_metrics(cw_client, [base_row])

    metric_data = get_all_metric_data(cw_client)

    query_metric = next(
        m for m in metric_data
        if m["MetricName"] == "GBScanned"
    )

    dimensions = {
        d["Name"]: d["Value"]
        for d in query_metric["Dimensions"]
    }

    assert dimensions["Asset"] == "mart_semantic_attention_base"
    assert dimensions["NodeType"] == "model"
    assert dimensions["Status"] == "SUCCESS"


def test_same_run_id_across_all_metrics(cw_client, base_row):

    rows = [base_row.copy() for _ in range(3)]

    send_metrics(cw_client, rows)

    metric_data = get_all_metric_data(cw_client)

    run_ids = {
        next(
            d["Value"]
            for d in m["Dimensions"]
            if d["Name"] == "RunId"
        )
        for m in metric_data
    }

    assert len(run_ids) == 1


def test_run_id_format(cw_client, base_row):

    send_metrics(cw_client, [base_row])

    metric_data = get_all_metric_data(cw_client)

    run_id = next(
        d["Value"]
        for d in metric_data[0]["Dimensions"]
        if d["Name"] == "RunId"
    )

    assert run_id.startswith("run-")
    assert len(run_id) == len("run-20260617-020134")


def test_correct_metric_values(cw_client, base_row):

    send_metrics(cw_client, [base_row])

    metric_data = get_all_metric_data(cw_client)

    by_name = {
        m["MetricName"]: m
        for m in metric_data
    }

    assert by_name["GBScanned"]["Value"] == 1.5
    assert by_name["GBScanned"]["Unit"] == "Gigabytes"

    assert by_name["DurationSeconds"]["Value"] == 42
    assert by_name["DurationSeconds"]["Unit"] == "Seconds"

    assert by_name["QueryCount"]["Value"] == 1
    assert by_name["QueryCount"]["Unit"] == "Count"

    assert by_name["RunDurationSeconds"]["Value"] == 42
    assert by_name["RunDurationSeconds"]["Unit"] == "Seconds"

    assert by_name["RunSuccess"]["Value"] == 1
    assert by_name["RunSuccess"]["Unit"] == "Count"

    assert by_name["RunTotal"]["Value"] == 1
    assert by_name["RunTotal"]["Unit"] == "Count"


# ── run-level metrics ────────────────────────────────────────────────────────

def test_run_duration_is_sum_of_query_durations(cw_client, base_row):

    rows = [
        base_row.copy(),
        {
            **base_row,
            "duration_seconds": 20
        }
    ]

    send_metrics(cw_client, rows)

    metric_data = get_all_metric_data(cw_client)

    run_metric = next(
        m for m in metric_data
        if m["MetricName"] == "RunDurationSeconds"
    )

    assert run_metric["Value"] == 62


def test_run_success_is_zero_when_failure_exists(cw_client, base_row):

    rows = [
        base_row.copy(),
        {
            **base_row,
            "status": "FAILURE"
        }
    ]

    send_metrics(cw_client, rows)

    metric_data = get_all_metric_data(cw_client)

    run_success = next(
        m for m in metric_data
        if m["MetricName"] == "RunSuccess"
    )

    assert run_success["Value"] == 0


# ── batching ────────────────────────────────────────────────────────────────

def test_batches_over_1000_metrics(cw_client, base_row):

    rows = [base_row.copy() for _ in range(334)]

    send_metrics(cw_client, rows)

    assert cw_client.put_metric_data.call_count >= 2


def test_multiple_rows_all_published(cw_client, base_row):

    rows = [base_row.copy() for _ in range(3)]

    send_metrics(cw_client, rows)

    metric_data = get_all_metric_data(cw_client)

    query_count_metrics = [
        m for m in metric_data
        if m["MetricName"] == "QueryCount"
    ]

    assert len(query_count_metrics) == 3


# ── mixed rows ───────────────────────────────────────────────────────────────

def test_skips_invalid_rows_publishes_valid(cw_client, base_row):

    rows = [
        {
            "query": "select 1",
            "gb_billed": 0,
            "duration_seconds": 0,
            "status": "SUCCESS",
            "creation_time": datetime(
                2026, 6, 1, 0, 0, 0,
                tzinfo=timezone.utc
            )
        },
        base_row,
    ]

    send_metrics(cw_client, rows)

    metric_data = get_all_metric_data(cw_client)

    assert any(
        m["MetricName"] == "GBScanned"
        for m in metric_data
    )

    query_count_metrics = [
        m for m in metric_data
        if m["MetricName"] == "QueryCount"
    ]

    assert len(query_count_metrics) == 1