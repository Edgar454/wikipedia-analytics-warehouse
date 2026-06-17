import pytest
from telemetry.aws_utils import extract_asset_name


@pytest.mark.parametrize("node_id,expected", [
    (
        "model.wikipedia.mart_semantic_attention_base",
        "mart_semantic_attention_base",
    ),
    (
        "seed.wikipedia.structural_roots",
        "structural_roots",
    ),
    (
        "test.wikipedia.not_null_analysis_key",
        "not_null_analysis_key",
    ),
])
def test_valid_node_ids(node_id, expected):
    assert extract_asset_name(node_id) == expected


@pytest.mark.parametrize("node_id", [
    None,
    "",
    "model.wikipedia",
    "model",
])
def test_invalid_node_ids_return_none(node_id):
    assert extract_asset_name(node_id) is None


def test_truncates_at_255_characters():
    long_name = "a" * 300
    node_id = f"model.wikipedia.{long_name}"
    assert len(extract_asset_name(node_id)) == 255