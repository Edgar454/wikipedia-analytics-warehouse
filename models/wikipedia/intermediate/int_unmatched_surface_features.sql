{{ config(materialized='view', tags=['mart' , 'intermediate']) }}

SELECT
    date_id,
    analysis_key,
    SPLIT(analysis_key, ':')[SAFE_OFFSET(2)] AS title,
    page_type,
    wiki_group,
    language_name,
    is_mobile,
    daily_views,

    MIN(date_id) OVER (PARTITION BY analysis_key) AS entity_first_appearance,
    MIN(date_id) OVER (PARTITION BY analysis_key, wiki_group) AS first_entity_appearance_in_wiki_group,

    SUM(daily_views) OVER (PARTITION BY analysis_key,wiki_group,language_name,is_mobile) AS entity_prominence,

    SUM(daily_views) OVER (
        PARTITION BY analysis_key,wiki_group,language_name,is_mobile
        ORDER BY UNIX_SECONDS(TIMESTAMP(date_id))
        RANGE BETWEEN 604800 PRECEDING AND CURRENT ROW
    ) AS persistence_score,

    LAG(daily_views) OVER (
        PARTITION BY analysis_key,wiki_group,language_name,is_mobile
        ORDER BY date_id
    ) AS prev_views

FROM {{ ref('mart_semantic_attention_base') }}
WHERE is_matched = FALSE
  AND page_type = 'article'