import json
from unittest.mock import MagicMock
from unittest.mock import patch

import pytest

from powerbi_api.client import PowerBIClient


SECRET = {
    "TENANT_ID": "tenant",
    "CLIENT_ID": "client",
    "CLIENT_SECRET": "secret",
    "FABRIC_EMAIL": "mail@to.com",
    "WORKSPACE_NAME": "workspace",
    "DATASET_NAME": "dataset",
}


@pytest.fixture
def client():

    with (
        patch.object(
            PowerBIClient,
            "_get_secret",
            return_value=SECRET,
        ),
        patch.object(
            PowerBIClient,
            "_authenticate",
            return_value="token",
        ),
        patch.object(
            PowerBIClient,
            "_get_workspace_id",
            return_value="workspace-id",
        ),
        patch.object(
            PowerBIClient,
            "_get_dataset_id",
            return_value="dataset-id",
        ),
    ):

        yield PowerBIClient("dummy-secret")


def test_get_secret():

    response = {
        "SecretString": json.dumps(SECRET)
    }

    secrets_client = MagicMock()
    secrets_client.get_secret_value.return_value = response

    obj = PowerBIClient.__new__(PowerBIClient)
    obj.region = "eu-north-1"
    obj.powerbi_secret = "dummy-secret"

    with patch(
        "boto3.client",
        return_value=secrets_client,
    ):

        secret = obj._get_secret()

        assert secret == SECRET


def test_authenticate():

    response = MagicMock()

    response.raise_for_status.return_value = None

    response.json.return_value = {
        "access_token": "my-token"
    }

    obj = PowerBIClient.__new__(PowerBIClient)

    obj.credentials = type(
        "Credentials",
        (),
        SECRET,
    )

    obj.session = MagicMock()

    obj.session.post.return_value = response

    token = obj._authenticate()

    assert token == "my-token"


def test_get_workspace_id(client):

    response = MagicMock()

    response.raise_for_status.return_value = None

    response.json.return_value = {
        "value": [
            {
                "id": "workspace-id",
                "name": "workspace",
            }
        ]
    }

    with patch.object(
        client.session,
        "get",
        return_value=response,
    ):
        assert client._get_workspace_id() == "workspace-id"


def test_get_dataset_id(client):

    response = MagicMock()

    response.raise_for_status.return_value = None

    response.json.return_value = {
        "value": [
            {
                "id": "dataset-id",
                "name": "dataset",
            }
        ]
    }

    with patch.object(
        client.session,
        "get",
        return_value=response,
    ):
        assert client._get_dataset_id() == "dataset-id"


def test_refresh(client):

    response = MagicMock()

    response.raise_for_status.return_value = None
    response.status_code = 202

    with patch.object(
        client.session,
        "post",
        return_value=response,
    ):
        assert client.refresh() is True


def test_try_create_returns_none():

    with patch.object(
        PowerBIClient,
        "__init__",
        side_effect=Exception,
    ):

        assert (
            PowerBIClient.try_create("dummy")
            is None
        )