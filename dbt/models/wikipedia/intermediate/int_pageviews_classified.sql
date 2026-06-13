{{ config(materialized='view', tags=['intermediate']) }}

WITH classified AS (
    SELECT
        p.*,
        COALESCE(c.page_type, 'article') AS page_type
    FROM {{ ref('stg_pageviews') }} p
    LEFT JOIN {{ ref('wiki_classifications') }} c
        ON (c.match_type = 'suffix' AND p.wiki LIKE c.pattern)
        OR (c.match_type = 'prefix' AND p.wiki LIKE c.pattern)
)

SELECT
    wiki,
    title,
    views,
    datehour,
    CASE
        WHEN title LIKE '%:%' THEN 'namespace'
        ELSE page_type
    END AS page_type
FROM classified