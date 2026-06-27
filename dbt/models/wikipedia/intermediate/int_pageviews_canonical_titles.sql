{{ config(materialized='view', tags=['intermediate']) }}
SELECT
    wiki,
    CASE
        WHEN page_type = 'namespace'
            AND canonical_namespace IS NOT NULL
            AND canonical_namespace != ''
        THEN CONCAT(
            canonical_namespace,
            ':',
            TRIM(SUBSTR(title, STRPOS(title, ':') + 1))
        )
        ELSE title
    END AS title,
    views,
    datehour,
    page_type
FROM {{ ref('int_pageviews_classified') }}