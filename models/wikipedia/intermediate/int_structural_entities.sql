{{ config(materialized='table',tags=['intermediate']) }}

WITH RECURSIVE structural_tree AS (

    -- Seed roots
    SELECT
        numeric_id
    FROM {{ ref('structural_roots') }}

    UNION ALL 

    -- Traverse subclass hierarchy
    SELECT
        w.numeric_id
    FROM {{ ref('stg_wikidata') }} w
    CROSS JOIN UNNEST(w.subclass_of) sc
    JOIN structural_tree st
        ON sc.numeric_id = st.numeric_id

) 

SELECT DISTINCT st.numeric_id
FROM structural_tree st