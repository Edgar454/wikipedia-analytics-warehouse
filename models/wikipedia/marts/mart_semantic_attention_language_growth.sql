{{ config(materialized='view' , tags=['marts','cross_language']) }}

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
    COUNT(DISTINCT wiki_group) OVER (PARTITION BY analysis_key, date_id) AS concurrent_language_count , 


    DENSE_RANK() OVER (
        PARTITION BY date_id, wiki_group
        ORDER BY daily_views DESC
    ) AS rank_in_language ,

        
    SAFE_DIVIDE(
        daily_views,
        AVG(daily_views) OVER (PARTITION BY wiki_group, date_id)
    ) AS relative_attention_in_language 
    
FROM {{ ref('mart_semantic_attention_base') }}
WHERE is_matched = TRUE
