import os
import json
import time
import logging

logger = logging.getLogger(__name__)

from powerbi_api.client import PowerBIClient
from powerbi_api.exceptions import PowerBIImportTimeoutError

class PowerBIDeployer(PowerBIClient):

    def __init__(self, pbix_path:str):
        super().__init__(resolve_assets=False , secret_source = "env")
        self.pbix_path = pbix_path
        self.gcp_credentials = os.getenv('GCP_SERVICE_ACCOUNT_KEY')
        self._parse_gcp_credentials()
    
    def _parse_gcp_credentials(self):
        """
        Load the Google BigQuery service account credentials
        provided by the deployment environment.

        The credentials are later uploaded to the Power BI
        datasource so scheduled refreshes can authenticate
        against BigQuery.
        """

        if not self.gcp_credentials:
            raise RuntimeError(
                "GCP_SERVICE_ACCOUNT_KEY environment variable not found."
            )

        content = json.loads(self.gcp_credentials)

        self.service_account_json = json.dumps(content)
        self.service_account_email = content["client_email"]
        self.project_id = content['project_id']

        logger.info(
            "Loaded Google service account '%s'.",
            self.service_account_email,
        )
    
    def _ensure_workspace(self,workspace_name ) -> str:
        """
        Retrieve the identifier of a Power BI workspace.

        If the workspace does not already exist, it is created and its
        identifier is returned.

        This method is intentionally idempotent, allowing deployment
        pipelines to be executed repeatedly without creating duplicate
        workspaces.
        """

        try:

            response = self.session.get(
                f"{self.BASE_URL}/groups",
                timeout=30,
            )
            response.raise_for_status()

            workspaces = response.json()["value"]

            for workspace in workspaces:

                if workspace["name"] == workspace_name:
                    logger.info(
                        "Using existing workspace '%s'.",
                        workspace_name,
                    )
                    return workspace["id"]



            response = self.session.post(
                f"{self.BASE_URL}/groups",
                json={
                    "name": workspace_name,
                },
                timeout=30,
            )
            response.raise_for_status()
            workspace_id = response.json()["id"]
            logger.info(
                "Created workspace '%s'.",
                workspace_name,
            )
            return workspace_id

        except Exception:
            raise

    def _add_workspace_admin(self, workspace_id:str , email:str) -> bool:
        """
        Grant a user administrator access to a workspace.

        This is primarily useful after a workspace has been created
        by a service principal so that a human administrator can
        immediately access it from the Power BI web UI.
        """
        response = self.session.get(
            f"{self.BASE_URL}/groups/{workspace_id}/users",
            timeout=30,
        )
        response.raise_for_status()

        existing_users = response.json()["value"]
        if any(u.get("emailAddress") == email for u in existing_users):
            logger.info("'%s' is already a workspace admin, skipping.", email)
            return True

        body = {
            "emailAddress": email,
            "groupUserAccessRight": "Admin",
        }

        response = self.session.post(
            f"{self.BASE_URL}/groups/{workspace_id}/users",
            json=body,
            timeout=30,
        )

        response.raise_for_status()
        logger.info(
            "Granted '%s' administrator access.",
            email,
        )
        return True
    
    def _upload_pbix(self, workspace_id: str, pbix_path: str,display_name: str,):
        """
        Upload a PBIX file into a Power BI workspace.

        Returns the import identifier. The dataset and report are created
        asynchronously and should be polled before continuing.
        """

        url = (
            f"{self.BASE_URL}/groups/{workspace_id}/imports"
            f"?datasetDisplayName={display_name}"
            "&nameConflict=CreateOrOverwrite"
        )
        
        with open(pbix_path, "rb") as f:
            response = self.session.post(
                url,
                files={
                    "file": (
                        os.path.basename(pbix_path),
                        f,
                        "application/octet-stream",
                    )
                },
                timeout=300,
            )
        if not response.ok:
            logger.error(
                "PBIX upload failed (%s): %s",
                response.status_code,
                response.text,
            )
            response.raise_for_status()
        
        payload = response.json()
        logger.info(
            "Successfully uploaded PBIX '%s'.",
            display_name,
        )
        return payload["id"]
    
    def _wait_import(self, workspace_id, import_id, poll_interval=2, max_attempts=2000):

        for attempt in range(max_attempts):
            response = self.session.get(
                f"{self.BASE_URL}/groups/{workspace_id}/imports/{import_id}",
                timeout=60,
            )
            response.raise_for_status()
            payload = response.json()
            state = payload["importState"]

            if state == "Succeeded":
                return payload
            if state == "Failed":
                raise RuntimeError(f"Import failed: {payload}")

            time.sleep(poll_interval)
            attempt += 1

        raise PowerBIImportTimeoutError(import_id, state, max_attempts)

    def _set_bigquery_credentials(self , gateway_id: str,datasource_id: str) -> bool:
        """
        Set BigQuery service-account credentials on an existing,
        auto-provisioned cloud datasource.

        No client-side encryption is required here -- RSA-OAEP only
        applies to on-premises gateways. Cloud datasources use
        encryptionAlgorithm "None", relying on HTTPS transport security
        alone, per Microsoft's own documented examples.
        """
        credentials_payload = json.dumps(
            {
                "credentialData": [
                    {"name": "username", "value": self.service_account_email},
                    {"name": "password", "value": self.service_account_json},
                ]
            }
        )

        body = {
            "credentialDetails": {
                "credentialType": "Basic",
                "credentials": credentials_payload,
                "encryptedConnection": "Encrypted",
                "encryptionAlgorithm": "None",
                "privacyLevel": "None",
            }
        }

        response = self.session.patch(
            f"{self.BASE_URL}/gateways/{gateway_id}"
            f"/datasources/{datasource_id}",
            json=body,
            timeout=30,
        )

        if not response.ok:
            logger.error(
                "Failed to configure BigQuery datasource: %s %s",
                response.status_code,
                response.text,
            )
            response.raise_for_status()

        return True

    def _update_parameter(self,parameter_name: str,value: str,) -> bool:
        """
        Update a single Power Query parameter on the deployed dataset.

        The parameter must already exist inside the PBIX.

        Changes become effective on the next dataset refresh.
        """

        body = {
            "updateDetails": [
                {
                    "name": parameter_name,
                    "newValue": value,
                }
            ]
        }

        response = self.session.post(
            f"{self.BASE_URL}/groups/"
            f"{self.workspace_id}/datasets/"
            f"{self.dataset_id}/Default.UpdateParameters",
            json=body,
            timeout=30,
        )

        response.raise_for_status()

        logger.info(
            "Updated parameter '%s' to '%s'.",
            parameter_name,
            value,
        )

        return True

    def _update_parameters(self, parameters: dict[str, str]) -> None:
        """
        Update multiple Power Query parameters.

        Parameters
        ----------
        parameters:
            Mapping of parameter names to their new values.
        """

        for parameter, value in parameters.items():
            self._update_parameter(parameter, value)
    
    def deploy(self):
        """
        Deploy the Power BI analytical application.

        The deployment workflow:

        - ensures the workspace exists,
        - grants administrator access,
        - uploads the PBIX file,
        - waits for import completion,
        - configures the BigQuery datasource,
        - triggers the initial dataset refresh.
        """

        try:

            logger.info(
                "Starting Power BI deployment."
            )

            workspace_id = self._ensure_workspace(
                self.credentials.WORKSPACE_NAME
            )

            self._add_workspace_admin(
                workspace_id,
                self.credentials.FABRIC_EMAIL
            )

            import_id = self._upload_pbix(
                workspace_id,
                self.pbix_path,
                self.credentials.DATASET_NAME,
            )

            import_result = self._wait_import(
                workspace_id,
                import_id,
            )

            self.workspace_id = workspace_id
            self.dataset_id = import_result["datasets"][0]["id"]

            bigquery_source = self._get_bigquery_datasource()

            self._set_bigquery_credentials(
                bigquery_source["gatewayId"],
                bigquery_source["datasourceId"],
            )

            self._update_parameter(
                "ProjectId",
                self.project_id,
            )

            self._update_parameter(
                "DatasetName",
                "dbt_dev",
            )

            self.refresh()

            logger.info(
                "Power BI deployment completed successfully."
            )

            return True

        except Exception:

            logger.exception(
                "Power BI deployment failed."
            )

            raise

       