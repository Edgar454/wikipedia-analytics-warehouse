import pytest
from telemetry.aws_utils import extract_node_id


def test_valid_query():
    query = """
    /* {"node_id":"model.wikipedia.mart_semantic_attention_base"} */
    select 1
    """
    assert extract_node_id(query) == "model.wikipedia.mart_semantic_attention_base"


def test_multiline_comment():
    query = """
    /*
    {"node_id":"model.wikipedia.mart_semantic_attention_base"}
    */
    select 1
    """
    assert extract_node_id(query) == "model.wikipedia.mart_semantic_attention_base"


@pytest.mark.parametrize("query", [
    None,
    "",
    "select 1",
    "create schema if not exists dbt_dev",
    "/* not json */",
    '/* {"no_node_id": "something"} */',
])
def test_invalid_queries_return_none(query):
    assert extract_node_id(query) is None