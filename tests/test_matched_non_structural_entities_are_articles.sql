{{ config(tags=['semantic_tests']) }}

SELECT *
FROM {{ ref('mart_semantic_attention_base') }}
WHERE is_structural_entity = FALSE
  AND is_matched = TRUE
  AND page_type <> 'article'