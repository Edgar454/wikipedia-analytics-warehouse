{{ config(materialized='view', tags=['star']) }}
SELECT
    f.numeric_id,
    COALESCE(
        w.en_label,
        w.fr_label,
        w.de_label,
        w.es_label,
        w.ja_label,
        w.id
    ) AS type_label,
    CASE
        WHEN w.numeric_id IN (
            SELECT numeric_id
            FROM {{ ref('int_structural_entities') }}
        ) THEN TRUE
        ELSE FALSE
    END AS is_structural,
    CASE
        WHEN w.subclass_of IS NULL THEN TRUE
        ELSE FALSE
    END AS is_leaf_like_type , 
    COUNT(*) AS frequency
FROM {{ ref('int_wikidata_instance_of') }} f
JOIN {{ ref('stg_wikidata') }} w
    ON f.numeric_id = w.numeric_id
GROUP BY 1, 2, 3 , 4
