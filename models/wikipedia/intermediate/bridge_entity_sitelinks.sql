{{ config(
    materialized='view',
    on_schema_change='sync_all_columns',
    tags=['intermediate' , 'bridge']
) }}

{#
NOTE: This table is expensive to rebuild (~3.6GB scan).
Do not include in regular dbt run cycles.
Rebuild manually only when wikidata snapshot is updated:
    dbt run --select bridge_entity_sitelinks --full-refresh
Prevent accidental rebuild by setting full_refresh: false in dbt_project.yml
#}

SELECT
    w.numeric_id,
    REPLACE(sl.site, 'wiki', '')    AS wiki_code,
    sl.site                          AS site,
    sl.title                         AS title_raw,
    sl.encoded                       AS title
FROM {{ ref('stg_wikidata') }} w,
UNNEST(w.sitelinks) AS sl
WHERE sl.encoded IS NOT NULL
AND w.numeric_id IS NOT NULL