{{ config(materialized='table' , tags=['marts','base']) }}

-- CTE 1: single scan of gold, hourly grain
WITH hourly AS (
    SELECT
        DATE(datehour) AS date_id,
        datehour,
        analysis_key,
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

-- CTE 3: classify long tail
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

-- CTE 4: collapse buckets
bucketed AS (
    SELECT
        date_id,
        analysis_key_bucket AS analysis_key,
        language_name,
        is_mobile,
        page_type,
        CASE 
            WHEN analysis_key_bucket = 'OTHER_MATCHED' THEN 'other'
            WHEN analysis_key_bucket = 'OTHER_UNMATCHED' THEN NULL
            ELSE entity_label 
        END AS entity_label,
        CASE 
            WHEN analysis_key_bucket = 'OTHER_MATCHED' THEN 'other'
            WHEN analysis_key_bucket = 'OTHER_UNMATCHED' THEN NULL
            ELSE entity_type_label
        END AS entity_type_label,
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

-- FINAL
SELECT
    b.*
FROM bucketed b
