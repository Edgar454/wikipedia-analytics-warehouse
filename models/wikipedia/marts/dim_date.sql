{{ config(materialized='table', tags=['star']) }}

WITH date_spine AS (

    SELECT
        datehour
    FROM UNNEST(
        GENERATE_TIMESTAMP_ARRAY(
            TIMESTAMP('2025-01-01'),
            TIMESTAMP('2026-12-31'),
            INTERVAL 1 HOUR
        )
    ) AS datehour

)

SELECT
    -- surrogate key (stable, deterministic)
    FORMAT_TIMESTAMP('%Y%m%d%H', datehour) AS date_id,

    datehour,

    EXTRACT(YEAR FROM datehour) AS year,
    EXTRACT(MONTH FROM datehour) AS month,
    EXTRACT(DAY FROM datehour) AS day,
    EXTRACT(DAYOFWEEK FROM datehour) AS day_of_week,
    EXTRACT(HOUR FROM datehour) AS hour,

    CASE
        WHEN EXTRACT(DAYOFWEEK FROM datehour) IN (1, 7)
        THEN TRUE ELSE FALSE
    END AS is_weekend,

    FORMAT_TIMESTAMP('%A', datehour) AS day_name,
    FORMAT_TIMESTAMP('%B', datehour) AS month_name

FROM date_spine