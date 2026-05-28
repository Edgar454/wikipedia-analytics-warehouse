{{ config(materialized='view', tags=['staging','raw']) }}

SELECT
    id,
    numeric_id,

    {% for lang in ['en', 'fr', 'ja', 'de', 'es'] %}
        {{ lang }}_label,
        {{ lang }}_wiki{% if not loop.last %},{% endif %}
    {% endfor %},

    instance_of,
    subclass_of,
    sitelinks , 
    type,
    CURRENT_TIMESTAMP() AS first_seen_in_pipeline

FROM {{ source('wikipedia','wikidata') }}