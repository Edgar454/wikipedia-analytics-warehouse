{{ config(materialized='view',  tags=['gold']) }}

SELECT
    f.pageview_id,
    f.datehour,
    f.wiki,
    f.title,
    f.views,
    f.page_type,

    COALESCE(l.language_name, 'unknown') AS language_name ,
    COALESCE(l.base_wiki, SPLIT(f.wiki, '.')[OFFSET(0)]) AS base_wiki,
    COALESCE(l.is_mobile, FALSE) AS is_mobile,
    COALESCE(l.wiki_group, f.wiki) AS wiki_group,

    d.year,
    d.month,
    d.day,
    d.hour,
    d.day_name,
    d.is_weekend,
    d.date_id , 

    b.numeric_id,
    e.en_label,
    e.first_instance_of_id,
    t2.type_label AS parent_type_label,

    t1.type_label AS entity_type_label ,
    t1.is_structural,
    t1.is_leaf_like_type,
    t1.frequency AS type_frequency,

    CASE WHEN b.numeric_id IS NOT NULL THEN TRUE ELSE FALSE END AS is_matched

FROM {{ ref('fact_pageviews') }} f
LEFT JOIN {{ ref('dim_languages') }} l 
    ON f.wiki = l.wiki_code
LEFT JOIN {{ ref('dim_date') }} d 
    ON FORMAT_TIMESTAMP('%Y%m%d%H', f.datehour) = d.date_id
LEFT JOIN {{ ref('bridge_entity_sitelinks') }} b
    ON SPLIT(f.wiki, '.')[OFFSET(0)] = b.wiki_code
    AND f.title = b.title
LEFT JOIN {{ ref('dim_entity') }} e 
    ON b.numeric_id = e.numeric_id
LEFT JOIN {{ ref('dim_entity_type') }} t1 
    ON e.numeric_id = t1.numeric_id
LEFT JOIN {{ ref('dim_entity_type') }} t2 
    ON e.first_instance_of_id = t2.numeric_id