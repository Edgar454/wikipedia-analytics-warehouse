{{ config(materialized='view' , tags=['marts', 'trends']) }}

SELECT
    date_id,
    analysis_key,
    entity_label,
    entity_type_label,
    wiki_group,
    language_name,
    is_mobile,
    page_type,
    is_matched,
    
    daily_views,
    peak_retention,
    growth_rate,
    attention_delta,
    growth_rate * SQRT(daily_views) AS momentum_score,
    SAFE_DIVIDE(std_3d_views, ma_3d_views) AS cv_3d_views,

    (ma_log_3d_views
    - LAG(ma_log_3d_views, 1) OVER (
        PARTITION BY analysis_key, wiki_group, language_name, is_mobile, page_type
        ORDER BY UNIX_SECONDS(TIMESTAMP(date_id))
    )) * ma_log_3d_views AS smoothed_daily_trend_score_3d ,

    (ma_log_3d_views
    - LAG(ma_log_3d_views, 7) OVER (
        PARTITION BY analysis_key, wiki_group, language_name, is_mobile, page_type
        ORDER BY UNIX_SECONDS(TIMESTAMP(date_id))
    )) * ma_log_3d_views  / 7 AS smoothed_trend_score_3d ,

    (
        SAFE_DIVIDE(std_3d_views, ma_3d_views)
        - LAG(SAFE_DIVIDE(std_3d_views, ma_3d_views), 7) OVER (
            PARTITION BY analysis_key,
                        wiki_group,
                        language_name,
                        is_mobile,
                        page_type
            ORDER BY UNIX_SECONDS(TIMESTAMP(date_id))
        )
    ) / 3 AS volatility_slope_3d ,

    SAFE_DIVIDE(
        daily_views - ma_previous_3d_views,
        std_previous_3d_views
    ) AS z_score_3d_views



FROM {{ ref('mart_semantic_attention_growth') }}
WHERE is_matched = TRUE