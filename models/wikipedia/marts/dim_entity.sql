{{ config(materialized='view', tags=['star']) }}

SELECT
    id AS entity_id,
    numeric_id,
    en_wiki,
    COALESCE(
        en_label,
        fr_label,
        de_label,
        es_label,
        ja_label,
        id
    ) AS entity_label,
    CASE
        WHEN numeric_id IN (
            SELECT numeric_id
            FROM {{ ref('int_structural_entities') }}
        ) THEN TRUE
        WHEN instance_of[SAFE_OFFSET(0)].numeric_id IN (
            SELECT numeric_id
            FROM {{ ref('int_structural_entities') }}
        ) THEN TRUE
        ELSE FALSE
    END AS is_structural,
    instance_of[SAFE_OFFSET(0)].numeric_id AS first_instance_of_id,
    instance_of ,
    first_seen_in_pipeline

FROM {{ ref('stg_wikidata') }}
