#!/usr/bin/env bash
set -e

eval "$(python telemetry/bootstrap.py)"

dbt deps --profiles-dir dbt

DBT_EXIT_CODE=0

dbt build \
  --profiles-dir dbt \
  --target prod \
  --select tag:marts || DBT_EXIT_CODE=$?

python telemetry/collect_metrics.py

exit $DBT_EXIT_CODE
