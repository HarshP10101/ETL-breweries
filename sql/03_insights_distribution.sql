-- sql/03_insights_distribution.sql
USE brewery_dw;

-- 03) Over-represented brewery types per state (lift vs US baseline)
WITH base AS (
  SELECT brewery_type, COUNT(*) AS n
  FROM v_breweries_clean
  WHERE country='United States'
    AND brewery_type IS NOT NULL
  GROUP BY brewery_type
),
base_total AS (
  SELECT SUM(n) AS total FROM base
),
state_type AS (
  SELECT state_province, brewery_type, COUNT(*) AS n
  FROM v_breweries_clean
  WHERE country='United States'
    AND state_province IS NOT NULL
    AND brewery_type IS NOT NULL
  GROUP BY state_province, brewery_type
),
state_total AS (
  SELECT state_province, SUM(n) AS total
  FROM state_type
  GROUP BY state_province
)
SELECT
  st.state_province,
  st.brewery_type,
  st.n AS state_type_count,
  ROUND(st.n / s.total, 6) AS state_share,
  ROUND(b.n / bt.total, 6) AS us_share,
  ROUND((st.n / s.total) / (b.n / bt.total), 3) AS lift
FROM state_type st
JOIN state_total s USING (state_province)
JOIN base b USING (brewery_type)
JOIN base_total bt
WHERE s.total >= 50 AND st.n >= 10
ORDER BY lift DESC
LIMIT 25;

-- 09) Top 3 brewery types per state (dense_rank)
WITH state_type AS (
  SELECT state_province, brewery_type, COUNT(*) AS n
  FROM v_breweries_clean
  WHERE country='United States'
    AND state_province IS NOT NULL
    AND brewery_type IS NOT NULL
  GROUP BY state_province, brewery_type
),
ranked AS (
  SELECT
    state_province, brewery_type, n,
    DENSE_RANK() OVER (PARTITION BY state_province ORDER BY n DESC) AS rnk
  FROM state_type
)
SELECT state_province, brewery_type, n
FROM ranked
WHERE rnk <= 3
ORDER BY state_province, rnk, n DESC;
