{{ config(materialized='view', tags=['marts', 'unmatched']) }}

SELECT
    date_id,
    analysis_key,
    title,
    page_type,
    wiki_group,
    language_name,
    is_mobile,
    daily_views,

    days_since_first_appearance,
    days_since_first_appearance_in_wiki_group,

    DATE_DIFF(
        date_id,
        days_since_first_appearance,
        DAY
    ) AS entity_age_hours ,

    DATE_DIFF(
        date_id,
        days_since_first_appearance_in_wiki_group,
        DAY
    ) AS entity_age_in_wiki_group_hours,

    entity_prominence,
    persistence_score,

    SAFE_DIVIDE(
        daily_views - prev_views,
        prev_views
    ) AS unmatched_velocity

FROM {{ ref('mart_unmatched_surface_features') }}