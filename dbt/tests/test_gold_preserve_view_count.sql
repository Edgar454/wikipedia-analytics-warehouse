{{ config(tags=[ 'unit_test' ,'reconciliation_tests']) }}
WITH comparison AS (

    SELECT
        SUM(views) AS fact_views
    FROM {{ ref('fact_pageviews') }}

),

gold AS (

    SELECT
        SUM(daily_views) AS gold_views
    FROM {{ ref('gold_pageviews_enriched') }}

),

final AS (

    SELECT
        ABS(c.fact_views - g.gold_views) / c.fact_views AS pct_diff
    FROM comparison c
    CROSS JOIN gold g

)

SELECT *
FROM final
WHERE pct_diff > 0.0001