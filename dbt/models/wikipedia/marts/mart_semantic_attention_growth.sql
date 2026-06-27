{{ config(materialized='view' , tags=['marts', 'base']) }}

WITH trends AS (
    SELECT
        *,
        LAG(daily_views) OVER (
            PARTITION BY
                analysis_key,
                language_name,
                is_mobile,
                page_type
            ORDER BY date_id
        ) AS prev_views
    FROM {{ ref('mart_semantic_attention_base') }}
)
SELECT
    date_id,
    analysis_key,
    entity_label,
    entity_type_label,
    page_type,
    language_name,
    is_mobile,
    is_matched,
    is_structural_entity ,

    daily_views ,
    SAFE_DIVIDE(daily_views, MAX(daily_views) OVER (PARTITION BY analysis_key)) AS peak_retention,

    SAFE_DIVIDE(
        daily_views -
        prev_views,
        prev_views
    ) AS growth_rate ,

    daily_views - prev_views AS attention_delta,

    AVG(daily_views) OVER (
        PARTITION BY analysis_key, language_name, is_mobile, page_type
        ORDER BY UNIX_SECONDS(TIMESTAMP(date_id))
        RANGE BETWEEN 259200 PRECEDING AND CURRENT ROW
    ) AS ma_3d_views,


    AVG(daily_views) OVER (
        PARTITION BY analysis_key, language_name, is_mobile, page_type
        ORDER BY UNIX_SECONDS(TIMESTAMP(date_id))
        RANGE BETWEEN 259200 PRECEDING AND 1 PRECEDING
    ) AS ma_previous_3d_views,

    AVG(LN(1+ daily_views)) OVER (
        PARTITION BY analysis_key, language_name, is_mobile, page_type
        ORDER BY UNIX_SECONDS(TIMESTAMP(date_id))
        RANGE BETWEEN 259200 PRECEDING AND CURRENT ROW
    ) AS ma_log_3d_views,

    STDDEV(daily_views) OVER (
        PARTITION BY analysis_key, language_name, is_mobile, page_type
        ORDER BY UNIX_SECONDS(TIMESTAMP(date_id))
        RANGE BETWEEN 259200 PRECEDING AND CURRENT ROW
    ) AS std_3d_views,

    STDDEV(daily_views) OVER (
        PARTITION BY analysis_key,  language_name, is_mobile, page_type
        ORDER BY UNIX_SECONDS(TIMESTAMP(date_id))
        RANGE BETWEEN 259200 PRECEDING AND 1 PRECEDING
    ) AS std_previous_3d_views


FROM trends
