{{ config(materialized='table' , tags=['marts', 'cross_language']) }}

SELECT 
    date_id,
    analysis_key,
    entity_label,
    entity_type_label , 
    page_type,
    wiki_group,
    language_name,
    is_mobile,
    is_matched,
    is_structural_entity,

    growth_rate ,
    rank_in_language ,
    relative_attention_in_language,

    AVG(growth_rate) OVER (
        PARTITION BY analysis_key , wiki_group
        ORDER BY UNIX_SECONDS(TIMESTAMP(date_id))
        RANGE BETWEEN 604800 PRECEDING AND CURRENT ROW
    ) AS rolling_avg_7d_growth_rate ,

    SUM(daily_views) OVER (
        PARTITION BY date_id, wiki_group
    ) AS language_daily_views,

    SAFE_DIVIDE(
        daily_views,
        SUM(daily_views) OVER (
            PARTITION BY date_id, wiki_group
        )
    ) AS attention_share , 

    STDDEV(rank_in_language) OVER (
        PARTITION BY analysis_key, date_id
    ) AS rank_dispersion

FROM {{ ref('mart_semantic_attention_language_growth') }}