
WITH daily AS (
    SELECT
        DATE(datehour) AS date_id,
        analysis_key,
        SUM(views) AS daily_views
    FROM {{ ref('gold_pageviews_enriched') }}
    GROUP BY 1, 2
),
total AS (
    SELECT SUM(daily_views) AS total_views FROM daily
),
thresholds AS (
    SELECT threshold FROM UNNEST([1,2,3,4, 5, 10, 25, 50, 100, 250, 500, 750, 1000, 2000, 5000]) AS threshold
)
SELECT
    t.threshold,
    ROUND(SUM(CASE WHEN d.daily_views < t.threshold THEN d.daily_views ELSE 0 END) / MAX(tot.total_views) * 100, 2) AS pct_views_in_other,
    ROUND(SUM(CASE WHEN d.daily_views < t.threshold THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_entities_in_other
FROM thresholds t
CROSS JOIN daily d
CROSS JOIN total tot
GROUP BY t.threshold
ORDER BY t.threshold;