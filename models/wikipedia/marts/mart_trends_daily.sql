{{ config(materialized='table' , tags=['marts', 'trends']) }}
SELECT
    date_id,
    analysis_key,
    entity_label,
    entity_type_label,
    page_type,
    wiki_group,
    language_name,
    is_mobile,
    is_matched,
    is_structural_entity ,

    SAFE_DIVIDE(daily_views, MAX(daily_views) OVER (PARTITION BY analysis_key)) AS peak_retention,

    SAFE_DIVIDE(
        daily_views -
        LAG(daily_views) OVER (
            PARTITION BY analysis_key
            ORDER BY date_id
        ),

        LAG(daily_views) OVER (
            PARTITION BY analysis_key
            ORDER BY date_id
        )
    ) AS growth_rate 

FROM {{ ref('mart_semantic_attention_base') }}
WHERE is_matched = TRUE