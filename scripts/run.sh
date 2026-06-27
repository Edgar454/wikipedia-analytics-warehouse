#!/usr/bin/env bash
set -e

# Load GCP credentials + env vars
eval "$(python telemetry/bootstrap.py)"

# Go to dbt project root
pushd dbt > /dev/null

  # install dependencies
  dbt deps --profiles-dir .

  DBT_EXIT_CODE=0

  # run models
  dbt run \
    --profiles-dir . \
    --target dev \
    --select tag:mart || DBT_EXIT_CODE=$?

popd > /dev/null

# collect metrics after dbt run
python telemetry/collect_metrics.py

# refresh power bi dashboard
python powerbi_api/refresh_dashboard

exit $DBT_EXIT_CODE