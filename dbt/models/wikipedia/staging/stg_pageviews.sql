{{ config(materialized='view', tags=['staging','filtered']) }}

SELECT
    wiki,
    title,
    views,
    datehour
FROM {{ ref('stg_pageviews_raw') }}
WHERE  wiki != ''
	AND wiki IS NOT NULL
	AND title != '-'
	AND REGEXP_CONTAINS(
		LOWER(title),
		r'\.(php|php3|php4|php5|phtml|cgi)$'
	)