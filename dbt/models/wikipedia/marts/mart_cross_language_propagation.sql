{{ config(materialized='table' , tags=['marts', 'cross_language']) }}

SELECT 
    date_id,
    analysis_key,
    entity_label,
    page_type,
    language_name,
    is_mobile,
    is_matched,
    is_structural_entity,

    daily_views ,
    COUNT(DISTINCT language_name) OVER (PARTITION BY analysis_key, date_id) AS concurrent_language_count ,

    ROUND(
        SAFE_DIVIDE(
            daily_views,
            SUM(daily_views) OVER (
                PARTITION BY date_id, language_name , is_mobile
            )
        ),
        5
    ) AS attention_share  

FROM {{ ref('mart_semantic_attention_growth') }}
WHERE is_matched = TRUE