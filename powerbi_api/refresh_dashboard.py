import os
from client import PowerBIClient

powerbi_secret_name = os.getenv("POWERBI_CREDENTIALS" , "wikipedia-analysis-powerbi-credentials")

powerbi = PowerBIClient.try_create(
    secret_name=powerbi_secret_name
)

if powerbi:
    powerbi.refresh()