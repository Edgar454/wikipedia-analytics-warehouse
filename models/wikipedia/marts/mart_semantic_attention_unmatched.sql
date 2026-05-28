{{ config(materialized='table', tags=['marts']) }}

SELECT
    date_id,
    analysis_key,
    title,
    page_type,
    wiki_group,
    language_name,
    is_mobile,
    daily_views,

    entity_first_appearance,
    first_entity_appearance_in_wiki_group,

    DATE_DIFF(
        date_id,
        entity_first_appearance,
        HOUR
    ) AS entity_age_hours ,

    DATE_DIFF(
        date_id,
        first_entity_appearance_in_wiki_group,
        HOUR
    ) AS entity_age_in_wiki_group_hours,

    entity_prominence,
    persistence_score,

    SAFE_DIVIDE(
        daily_views - prev_views,
        prev_views
    ) AS unmatched_velocity

FROM {{ ref('int_unmatched_surface_features') }}