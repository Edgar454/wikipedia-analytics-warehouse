{{ config(materialized='table' , tags=['marts']) }}

SELECT
    year,
    month,
    day,

    wiki_group,
    language_name,
    is_mobile,

    SUM(views) AS total_views,
    COUNT(*) AS pageviews,
    COUNT(DISTINCT title) AS unique_pages,

    SAFE_DIVIDE(
        SUM(views),
        SUM(SUM(views)) OVER (PARTITION BY year, month, day)
    ) AS share_of_global_views,

    SAFE_DIVIDE(
        SUM(CASE WHEN is_matched THEN views ELSE 0 END),
        SUM(views)
    ) AS match_rate_weighted,

    SUM(CASE WHEN is_mobile THEN views ELSE 0 END) AS mobile_views

FROM {{ ref('gold_pageviews_enriched') }}

GROUP BY
    year, month, day,
    wiki_group,
    language_name,
    is_mobile