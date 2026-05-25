{{ config(materialized='view',tags=['intermediate']) }}

SELECT
    w1.en_wiki,
    io.numeric_id
FROM {{ ref('stg_wikidata') }} w1
CROSS JOIN UNNEST(w1.instance_of) AS io
WHERE w1.en_wiki IS NOT NULL