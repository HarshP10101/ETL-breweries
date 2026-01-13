-- sql/02_insights_concentration.sql
USE brewery_dw;

-- 02) Market fragmentation index (HHI) by state
-- High HHI => a few cities dominate the state.
WITH city_counts AS (
  SELECT state_province, city, COUNT(*) AS breweries
  FROM v_breweries_clean
  WHERE country='United States'
    AND state_province IS NOT NULL
    AND city IS NOT NULL
  GROUP BY state_province, city
),
state_totals AS (
  SELECT state_province, SUM(breweries) AS total
  FROM city_counts
  GROUP BY state_province
),
shares AS (
  SELECT
    c.state_province,
    c.city,
    c.breweries,
    (c.breweries / t.total) AS share
  FROM city_counts c
  JOIN state_totals t USING (state_province)
)
SELECT
  state_province,
  ROUND(SUM(share * share), 6) AS hhi_city_concentration,
  COUNT(*) AS cities
FROM shares
GROUP BY state_province
HAVING COUNT(*) >= 10
ORDER BY hhi_city_concentration DESC
LIMIT 15;

-- 07) Diversity score per state (Shannon entropy across brewery types)
-- Higher entropy => more diverse type mix.
WITH state_type AS (
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
),
p AS (
  SELECT
    st.state_province,
    st.brewery_type,
    (st.n / t.total) AS p
  FROM state_type st
  JOIN state_total t USING (state_province)
)
SELECT
  state_province,
  ROUND(-SUM(p * LN(p)), 6) AS shannon_entropy,
  COUNT(*) AS type_count
FROM p
WHERE p > 0
GROUP BY state_province
HAVING type_count >= 4
ORDER BY shannon_entropy DESC
LIMIT 15;
