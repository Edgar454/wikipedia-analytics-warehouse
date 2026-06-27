from client import PowerBIClient

powerbi = PowerBIClient.try_create(
    "wikipedia-analysis-powerbi-credentials"
)

if powerbi:
    powerbi.refresh()