{{ config(materialized='view', tags=['staging','raw']) }}

{# 
NOTE: Designed as incremental for production use.
Incremental materialization requires DML, unavailable in BigQuery sandbox.
Switch to the following config when billing is enabled:

config(
    materialized='incremental'
)

if is_incremental():
    WHERE datehour >= TIMESTAMP_SUB(
        (SELECT MAX(datehour) FROM this),
        INTERVAL 1 HOUR
    )
else:
    WHERE datehour >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
#}

SELECT
    wiki,
    title,
    views,
    datehour
FROM {{ source('wikipedia', 'pageviews_2026') }}
WHERE datehour >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY))