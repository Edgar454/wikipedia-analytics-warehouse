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

    ROUND(momentum_score, 5) AS momentum_score,
    ROUND(smoothed_daily_trend_score_3d, 5) AS smoothed_daily_trend_score_3d ,
    ROUND(z_score_3d_views, 5) AS z_score_3d_views

FROM {{ ref('mart_trends_daily') }}




