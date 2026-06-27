{{ config(materialized='view', tags=['intermediate']) }}

WITH classified AS (
    SELECT
        p.*,
        COALESCE(c.page_type, 'article') AS page_type
    FROM {{ ref('stg_pageviews') }} p
    LEFT JOIN {{ ref('wiki_classifications') }} c
        ON (c.match_type = 'suffix' AND p.wiki LIKE c.pattern)
        OR (c.match_type = 'prefix' AND p.wiki LIKE c.pattern)
),

with_prefix AS (
    SELECT
        *,
        CASE
            WHEN STRPOS(title, ':') > 0
            THEN TRIM(SPLIT(title, ':')[SAFE_OFFSET(0)])
            ELSE NULL
        END AS title_prefix
    FROM classified
)

SELECT
    w.wiki,
    w.title,
    w.views,
    w.datehour,
    w.title_prefix,
    n.canonical_namespace,
    CASE
        WHEN w.title_prefix IS NOT NULL
            AND n.namespace_name IS NOT NULL
            AND n.namespace_name != ''
        THEN 'namespace'
        ELSE w.page_type
    END AS page_type
FROM with_prefix w
LEFT JOIN {{ ref('dim_namespaces') }} n
    ON n.wiki_code = SPLIT(w.wiki, '.')[OFFSET(0)]
    AND LOWER(n.namespace_name) = LOWER(w.title_prefix)
    AND n.namespace_name != ''