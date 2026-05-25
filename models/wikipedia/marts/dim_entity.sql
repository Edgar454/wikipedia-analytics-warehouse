{{ config(materialized='view', tags=['star']) }}

SELECT
    id AS entity_id,
    numeric_id,
    en_wiki,
    en_label,
    instance_of[SAFE_OFFSET(0)].numeric_id AS first_instance_of_id,
    instance_of, 
    gender,
    date_of_birth,
    date_of_death,
    place_of_birth,
    worked_at,
    country,
    country_of_citizenship,
    educated_at,
    occupation,
    instrument,
    genre,
    industry,
    coordinate_location,
    first_seen_in_pipeline

FROM {{ ref('stg_wikidata') }}
