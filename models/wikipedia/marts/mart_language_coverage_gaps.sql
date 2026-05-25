{{ config(materialized='table', tags=['marts', 'debug']) }}

SELECT
    wiki,
    COUNT(*) AS pageviews,
    SUM(views) AS total_views
FROM {{ ref('gold_pageviews_enriched') }}
WHERE language_name = 'unknown' AND page_type='article'
GROUP BY 1
ORDER BY total_views DESC