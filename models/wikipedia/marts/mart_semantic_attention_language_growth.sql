{{ config(materialized='view' , tags=['marts']) }}

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

    total_views ,
    COUNT(DISTINCT wiki_group) OVER (PARTITION BY analysis_key, date_id) AS concurrent_language_count , 

    SAFE_DIVIDE(
        total_views -
        LAG(total_views) OVER (
            PARTITION BY analysis_key,wiki_group,language_name,is_mobile
            ORDER BY date_id
        ),

        LAG(total_views) OVER (
            PARTITION BY analysis_key,wiki_group,language_name,is_mobile
            ORDER BY date_id
        )
    ) AS growth_rate ,

    DENSE_RANK() OVER (
        PARTITION BY date_id, wiki_group
        ORDER BY total_views DESC
    ) AS rank_in_language ,

        
    SAFE_DIVIDE(
        total_views,
        AVG(total_views) OVER (PARTITION BY wiki_group, date_id)
    ) AS relative_attention_in_language 
    
FROM {{ ref('mart_semantic_attention_base') }}
WHERE is_matched = TRUE
