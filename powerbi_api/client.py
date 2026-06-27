"""
Minimal Power BI REST client used by the Wikipedia Observatory.

This client authenticates using the OAuth2 client credentials flow,
discovers the configured workspace and semantic model at runtime,
then triggers an asynchronous dataset refresh.

The client intentionally does not wait for refresh completion.
Once Power BI acknowledges the refresh request (HTTP 202),
execution responsibility is delegated to the Power BI service,
allowing the ECS task to terminate immediately.
"""
import os
import json
import logging

import boto3
import requests

from powerbi_api.models import Credentials


logger = logging.getLogger(__name__)


class PowerBIClient:
    """
    Small wrapper around the Power BI REST API.

    During initialization the client:

    - authenticates against Microsoft Entra ID,
    - creates an authenticated HTTP session,
    - resolves the configured workspace,
    - resolves the configured dataset.

    Workspace and dataset identifiers are intentionally resolved
    at runtime rather than stored in configuration to avoid
    coupling deployments to environment-specific UUIDs.
    """

    BASE_URL = "https://api.powerbi.com/v1.0/myorg"

    def __init__(self, secret_name: str):
        self.region = os.getenv("AWS_REGION","eu-north-1")
        self.powerbi_secret = secret_name

        self.credentials = Credentials.model_validate(
            self._get_secret()
        )

        self.session = requests.Session()

        access_token = self._authenticate()

        self.session.headers.update(
            {
                "Authorization": f"Bearer {access_token}"
            }
        )

        self.workspace_id = self._get_workspace_id()
        self.dataset_id = self._get_dataset_id()

    @classmethod
    def try_create(cls, secret_name: str):
        try:
            return cls(secret_name)
        except Exception:
            logger.warning(
                "Power BI integration unavailable. Skipping refresh."
            )
            return None
    
    def _get_secret(self):
        """
        Retrieve Power BI credentials from AWS Secrets Manager.

        Credentials are intentionally stored in AWS rather than
        provided through environment variables in order to centralize
        secret management and avoid exposing OAuth credentials in the
        container configuration.

        The retrieved payload is validated using Pydantic before
        being used by the client.
        """
        client = boto3.client("secretsmanager", region_name=self.region) 
        response = client.get_secret_value(SecretId=self.powerbi_secret)
        return json.loads(response["SecretString"])

    def _authenticate(self) -> str:
        """
        Authenticate using the OAuth2 client credentials flow.

        Since the application executes as a short-lived ECS/Fargate
        batch task, token renewal is intentionally omitted.
        A single access token is sufficient for the lifetime
        of the pipeline.
        """

        token_url = (
            f"https://login.microsoftonline.com/"
            f"{self.credentials.TENANT_ID}/oauth2/v2.0/token"
        )

        payload = {
            "grant_type": "client_credentials",
            "client_id": self.credentials.CLIENT_ID,
            "client_secret": self.credentials.CLIENT_SECRET,
            "scope": "https://analysis.windows.net/powerbi/api/.default",
        }

        try:

            response = self.session.post(
                token_url,
                data=payload,
                timeout=30,
            )

            response.raise_for_status()

            logger.info(
                "Successfully authenticated with Microsoft Entra ID."
            )

            return response.json()["access_token"]

        except Exception:

            logger.exception(
                "Failed to authenticate against Microsoft Entra ID."
            )
            raise

    def _get_workspace_id(self) -> str:
        """
        Resolve the workspace identifier from its display name.

        Workspace names are stable deployment identifiers while
        workspace UUIDs may change if a workspace is recreated.
        """

        try:

            response = self.session.get(
                f"{self.BASE_URL}/groups",
                timeout=30,
            )

            response.raise_for_status()

            workspaces = response.json()["value"]

            for workspace in workspaces:

                if workspace["name"] == self.credentials.WORKSPACE_NAME:

                    logger.info(
                        "Resolved workspace '%s'.",
                        self.credentials.WORKSPACE_NAME,
                    )

                    return workspace["id"]

            raise ValueError(
                f"Workspace '{self.credentials.WORKSPACE_NAME}' not found."
            )

        except Exception:

            logger.exception(
                "Failed to resolve Power BI workspace."
            )
            raise

    def _get_dataset_id(self) -> str:
        """
        Resolve the semantic model identifier from its display name.

        Dataset identifiers are discovered dynamically in order
        to keep configuration portable across environments.
        """

        try:

            response = self.session.get(
                f"{self.BASE_URL}/groups/"
                f"{self.workspace_id}/datasets",
                timeout=30,
            )

            response.raise_for_status()

            datasets = response.json()["value"]

            for dataset in datasets:

                if dataset["name"] == self.credentials.DATASET_NAME:

                    logger.info(
                        "Resolved dataset '%s'.",
                        self.credentials.DATASET_NAME,
                    )

                    return dataset["id"]

            raise ValueError(
                f"Dataset '{self.credentials.DATASET_NAME}' not found."
            )

        except Exception:

            logger.exception(
                "Failed to resolve Power BI dataset."
            )
            raise
    
    def refresh(self) -> bool:
        """
        Trigger an asynchronous dataset refresh.

        Power BI returns HTTP 202 when the refresh request has
        been accepted.

        The client intentionally does not wait for refresh
        completion. Once the request has been accepted,
        refresh execution becomes the responsibility of
        the Power BI service.
        """

        try:

            response = self.session.post(
                f"{self.BASE_URL}/groups/"
                f"{self.workspace_id}/datasets/"
                f"{self.dataset_id}/refreshes",
                timeout=30,
            )

            response.raise_for_status()

            if response.status_code != 202:
                raise RuntimeError(
                    f"Unexpected response: {response.status_code}"
                )

            logger.info(
                "Successfully triggered Power BI dataset refresh."
            )

            return True

        except Exception:

            logger.exception(
                "Failed to trigger Power BI dataset refresh."
            )
            raise