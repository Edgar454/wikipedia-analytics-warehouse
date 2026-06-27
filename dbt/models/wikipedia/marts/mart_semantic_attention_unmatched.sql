{{ config(materialized='table', tags=['marts', 'unmatched']) }}

SELECT
    date_id,
    analysis_key,
    SPLIT(analysis_key, ':')[SAFE_OFFSET(2)] AS title,
    page_type,
    language_name,
    is_mobile,
    daily_views ,
    ROUND(
        (ma_log_3d_views
        - LAG(ma_log_3d_views, 3) OVER (
            PARTITION BY analysis_key, language_name, is_mobile, page_type
            ORDER BY UNIX_SECONDS(TIMESTAMP(date_id))
        )) * ma_log_3d_views / 3 ,
        5
    ) AS smoothed_trend_score 

FROM {{ ref('mart_semantic_attention_growth') }}
WHERE is_matched = FALSE