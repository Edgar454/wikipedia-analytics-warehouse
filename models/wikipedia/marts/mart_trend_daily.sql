{{ config(materialized='table', tags=['marts']) }}

SELECT
    year,
    month,
    day,

    SUM(views) AS total_views,
    COUNT(DISTINCT pageview_id) AS total_pageviews,

    COUNT(DISTINCT title) AS unique_pages,
    COUNT(DISTINCT wiki) AS active_wikis,

    SUM(CASE WHEN page_type = 'article' THEN views ELSE 0 END) AS article_views,
    SUM(CASE WHEN page_type != 'article' THEN views ELSE 0 END) AS non_article_views,

    SAFE_DIVIDE(
        SUM(CASE WHEN page_type = 'article' THEN views ELSE 0 END),
        SUM(views)
    ) AS article_ratio

FROM {{ ref('gold_pageviews_enriched') }}

GROUP BY
    year,
    month,
    day