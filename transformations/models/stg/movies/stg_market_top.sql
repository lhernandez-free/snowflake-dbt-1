{{
    config(
        post_hook = [
            "ALTER WAREHOUSE {{ env_var('DBT_XSMALL_VW') }} SUSPEND;"
        ]
    )
}}
WITH EPHEMERAL_ONE AS (
    SELECT * FROM {{ ref('stg_market_ephemeral_one') }}
),
EPHEMERAL_TWO AS (
    SELECT * FROM {{ ref('stg_market_ephemeral_two') }}
)
SELECT * 
FROM (
  SELECT *
  FROM EPHEMERAL_ONE
  UNION ALL
  SELECT *
  FROM EPHEMERAL_TWO
)
ORDER BY NUMBER_REGION
