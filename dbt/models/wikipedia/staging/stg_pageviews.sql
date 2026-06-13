{{ config(materialized='view', tags=['staging','filtered']) }}

SELECT
    wiki,
    title,
    views,
    datehour
FROM {{ ref('stg_pageviews_raw') }}
WHERE title NOT IN ('-', 'Index.php')
AND wiki != ''
AND wiki IS NOT NULL