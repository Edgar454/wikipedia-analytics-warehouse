{{ config(materialized='view' , tags=['marts', 'cross_language']) }}

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

    daily_views ,
    concurrent_language_count,
    rank_in_language ,
    relative_attention_in_language,


    SAFE_DIVIDE(
        daily_views,
        SUM(daily_views) OVER (
            PARTITION BY date_id, wiki_group , is_mobile
        )
    ) AS attention_share , 

    STDDEV(rank_in_language) OVER (
        PARTITION BY analysis_key, date_id , is_mobile
    ) AS rank_dispersion

FROM {{ ref('mart_semantic_attention_language_growth') }}