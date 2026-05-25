{{ config(materialized='table' , tags=['marts']) }}

SELECT
    year,
    month,
    day,
    page_type,

    SUM(views) AS total_views,
    COUNT(*) AS pageviews,

    SAFE_DIVIDE(
        SUM(views),
        SUM(SUM(views)) OVER (PARTITION BY year, month, day)
    ) AS share_of_daily_views

FROM {{ ref('gold_pageviews_enriched') }}

GROUP BY
    year,
    month,
    day,
    page_type