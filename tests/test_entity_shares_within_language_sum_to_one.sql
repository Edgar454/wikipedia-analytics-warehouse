-- tests/test_attention_share_sums_to_one.sql

WITH attention AS (

    SELECT
        date_id,
        wiki_group,
        is_mobile,
        SUM(attention_share) AS total_share

    FROM {{ ref('mart_cross_language_propagation') }}

    GROUP BY 1,2,3

)

SELECT *

FROM attention

WHERE ABS(total_share - 1) > 0.01