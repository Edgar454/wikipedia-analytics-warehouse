{{ config(materialized='view' , tags=['star']) }}

{#
NOTE: Designed as incremental for production use.
Switch config to:
    materialized='incremental',
    unique_key='pageview_id'
And add after WHERE clause:
    {% if is_incremental() %}
    AND datehour > (SELECT MAX(datehour) FROM {{ this }})
    {% endif %}
#}

SELECT
    wiki,
    title,
    views,
    datehour,
    page_type,
    CONCAT(wiki, '|', title, '|', CAST(datehour AS STRING)) AS pageview_id
FROM {{ ref('int_pageviews_canonical_titles') }}
