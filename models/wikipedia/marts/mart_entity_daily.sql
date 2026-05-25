{{ config(materialized='table' , tags=['marts']) }}

SELECT
    year,
    month,
    day,
    date_id,

    numeric_id,
    en_label,
    entity_type_label,
    is_structural,

    SUM(views) AS total_views,
    COUNT(*) AS pageviews,

    SAFE_DIVIDE(
        SUM(views),
        SUM(SUM(views)) OVER (PARTITION BY date_id)
    ) AS share_of_daily_views,

    SUM(SUM(views)) OVER (
        PARTITION BY numeric_id
        ORDER BY date_id
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_7d_views

FROM {{ ref('gold_pageviews_enriched') }} 
WHERE is_structural = FALSE
GROUP BY 1,2,3,4,5,6,7,8