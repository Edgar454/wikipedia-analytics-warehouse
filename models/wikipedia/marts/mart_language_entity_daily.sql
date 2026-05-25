{{ config(materialized='table', tags=['marts']) }}

SELECT
    year,
    month,
    day,

    language_name,
    wiki_group,

    entity_type_label,
    is_structural,

    SUM(views) AS total_views,
    COUNT(DISTINCT title) AS unique_pages,

    SAFE_DIVIDE(
        SUM(views),
        SUM(SUM(views)) OVER (PARTITION BY year, month, day, wiki_group)
    ) AS share_within_language

FROM {{ ref('gold_pageviews_enriched') }}

GROUP BY
    year,
    month,
    day,
    language_name,
    wiki_group,
    entity_type_label,
    is_structural