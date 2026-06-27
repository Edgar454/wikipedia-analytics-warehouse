-- tests/test_classified_preserve_view_count.sql
{{ config(tags=['unit_test', 'reconciliation_tests']) }}

WITH source AS (
    SELECT SUM(views) AS source_views FROM {{ ref('stg_pageviews') }}
),
classified AS (
    SELECT SUM(views) AS classified_views FROM {{ ref('int_pageviews_classified') }}
)
SELECT * FROM source s
CROSS JOIN classified c
WHERE s.source_views != c.classified_views