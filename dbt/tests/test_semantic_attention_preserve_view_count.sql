WITH fact_total AS (

SELECT
SUM(views) AS total_views

FROM {{ ref('gold_pageviews_enriched') }}

),

mart_total AS (

SELECT
SUM(daily_views) AS total_views

FROM {{ ref('mart_semantic_attention_base') }}

)

SELECT *

FROM fact_total f
CROSS JOIN mart_total m

WHERE f.total_views != m.total_views
