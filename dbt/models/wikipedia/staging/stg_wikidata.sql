{{ config(materialized='view', tags=['staging','filtered']) }}

SELECT *
FROM {{ ref('stg_wikidata_raw') }}
WHERE type = 'item' 