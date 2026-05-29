{{ config(materialized='table' , tags=['marts','base']) }}

-- CTE 1: single scan of gold, hourly grain
WITH hourly AS (
    SELECT
        DATE(datehour) AS date_id,
        datehour,
        analysis_key,
        wiki_group,
        language_name,
        is_mobile,
        page_type,
        entity_label,
        entity_type_label,
        is_matched,
        is_structural_entity,
        SUM(views) AS hourly_views
    FROM {{ ref('gold_pageviews_enriched') }}
    GROUP BY 1,2,3,4,5,6,7,8,9,10,11
),

-- CTE 2: daily grain (derived from hourly, no gold scan)
daily AS (
    SELECT
        date_id,
        analysis_key,
        wiki_group,
        language_name,
        is_mobile,
        page_type,
        entity_label,
        entity_type_label,
        is_matched,
        is_structural_entity,
        SUM(hourly_views) AS daily_views
    FROM hourly
    GROUP BY 1,2,3,4,5,6,7,8,9,10
),

-- CTE 3: entity peak (derived from hourly, no gold scan)
entity_peak AS (
    SELECT
        date_id,
        analysis_key,
        ARRAY_AGG(datehour ORDER BY hourly_views DESC LIMIT 1)[OFFSET(0)] AS peak_hour,
        MAX(hourly_views) AS peak_views
    FROM hourly
    GROUP BY 1, 2
),

-- CTE 4: classify long tail
classified AS (
    SELECT
        *,
        CASE
            WHEN SUM(daily_views) OVER (PARTITION BY date_id, analysis_key) < 1000 AND is_matched = TRUE THEN 'OTHER_MATCHED'
            WHEN SUM(daily_views) OVER (PARTITION BY date_id, analysis_key) < 1000 AND is_matched = FALSE THEN 'OTHER_UNMATCHED'
            ELSE analysis_key
        END AS analysis_key_bucket
    FROM daily
),

-- CTE 5: collapse buckets
bucketed AS (
    SELECT
        date_id,
        analysis_key_bucket AS analysis_key,
        wiki_group,
        language_name,
        is_mobile,
        page_type,
        CASE WHEN analysis_key_bucket LIKE 'OTHER%' THEN NULL ELSE entity_label END AS entity_label,
        CASE WHEN analysis_key_bucket LIKE 'OTHER%' THEN NULL ELSE entity_type_label END AS entity_type_label,
        CASE
            WHEN analysis_key_bucket = 'OTHER_MATCHED' THEN TRUE
            WHEN analysis_key_bucket = 'OTHER_UNMATCHED' THEN FALSE
            ELSE is_matched
        END AS is_matched,
        CASE WHEN analysis_key_bucket LIKE 'OTHER%' THEN FALSE ELSE is_structural_entity END AS is_structural_entity,
        SUM(daily_views) AS daily_views
    FROM classified
    GROUP BY 1,2,3,4,5,6,7,8,9,10
)

-- FINAL: join peaks — safe, grain matches
SELECT
    b.*,
    p.peak_hour,
    p.peak_views,
    SAFE_DIVIDE(
        b.daily_views,
        SUM(b.daily_views) OVER (PARTITION BY b.date_id)
    ) AS share_global,
    SAFE_DIVIDE(
        b.daily_views,
        SUM(b.daily_views) OVER (PARTITION BY b.date_id, b.wiki_group)
    ) AS share_wiki_group
FROM bucketed b
LEFT JOIN entity_peak p
    ON b.date_id = p.date_id
    AND b.analysis_key = p.analysis_key