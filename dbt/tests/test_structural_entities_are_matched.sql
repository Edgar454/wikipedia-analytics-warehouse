{{ config(tags=['unit_test' ,'semantic_tests']) }}
SELECT *
FROM {{ ref('mart_semantic_attention_base') }}
WHERE is_structural_entity = TRUE
  AND is_matched = FALSE