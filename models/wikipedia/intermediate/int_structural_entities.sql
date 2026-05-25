{{ config(materialized='view',tags=['intermediate']) }}

SELECT DISTINCT
    w.numeric_id
FROM {{ ref('stg_wikidata') }} w
CROSS JOIN UNNEST(w.subclass_of) sc
JOIN {{ ref('structural_roots') }} r
    ON sc.numeric_id = r.numeric_id