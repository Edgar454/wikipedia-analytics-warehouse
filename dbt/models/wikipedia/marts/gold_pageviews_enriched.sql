{{ config(materialized='view',  tags=['gold']) }}

{# 
NOTE: Many queries reuse it dowmstream so this model should be materialized as table but due to the sandbox limitations
 this will stay as a view
#}

SELECT
    f.pageview_id,
    f.datehour,
    f.wiki,
    f.title,
    f.views,
    f.page_type,

    COALESCE(l.language_name, 'other') AS language_name ,
    COALESCE(l.is_mobile, FALSE) AS is_mobile,

    d.year,
    d.month,
    d.day,
    d.hour,
    d.day_name,
    d.date_id , 

    b.numeric_id,
    e.first_instance_of_id,
    e.entity_label AS entity_label,
    COALESCE(entity_type.entity_label, 'unclassified') AS entity_type_label,
    CASE 
        WHEN e.is_structural IS TRUE THEN TRUE 
        ELSE FALSE
    END AS is_structural_entity,
    CASE 
        WHEN b.numeric_id IS NOT NULL THEN TRUE 
        ELSE FALSE 
    END AS is_matched , 
    
    CASE 
        WHEN b.numeric_id IS NOT NULL THEN CONCAT('E:', b.numeric_id) 
        ELSE CONCAT('T:', f.wiki, ':', f.title) 
    END AS analysis_key


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
LEFT JOIN {{ ref('dim_entity') }} entity_type
    ON e.first_instance_of_id = entity_type.numeric_id
