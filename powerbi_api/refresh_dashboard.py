import os
from powerbi_api.client import PowerBIClient

powerbi_secret_name = os.getenv("POWERBI_SECRET_NAME" , "wikipedia-analysis-powerbi-credentials")

powerbi = PowerBIClient.try_create(
    secret_name=powerbi_secret_name
)

if powerbi:
    powerbi.refresh()
