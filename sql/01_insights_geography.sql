-- sql/01_insights_geography.sql
USE brewery_dw;

-- 01) Brewery density leaders (normalized by city coverage)
-- Interprets “density” as average breweries per city in each state.
WITH city_counts AS (
  SELECT country, state_province, city, COUNT(*) AS breweries
  FROM v_breweries_clean
  WHERE country = 'United States'
    AND state_province IS NOT NULL
    AND city IS NOT NULL
  GROUP BY country, state_province, city
),
state_rollup AS (
  SELECT
    state_province,
    SUM(breweries) AS breweries_total,
    COUNT(*) AS cities_with_breweries,
    ROUND(AVG(breweries), 2) AS avg_breweries_per_city
  FROM city_counts
  GROUP BY state_province
)
SELECT *
FROM state_rollup
ORDER BY avg_breweries_per_city DESC, breweries_total DESC
LIMIT 15;

-- 04) Geo coverage score by state (data completeness metric)
SELECT
  state_province,
  COUNT(*) AS breweries,
  SUM(CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 ELSE 0 END) AS with_geo,
  ROUND(100 * SUM(CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS geo_coverage_pct
FROM v_breweries_clean
WHERE country='United States'
  AND state_province IS NOT NULL
GROUP BY state_province
HAVING COUNT(*) >= 30
ORDER BY geo_coverage_pct ASC, breweries DESC
LIMIT 20;

-- 05) Outlier cities by max intra-city distance (geo anomaly signal)
-- Note: This is expensive (pairwise). Use for profiling, not dashboards.
WITH base AS (
  SELECT brewery_id, city, state_province, latitude, longitude
  FROM v_breweries_clean
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL
    AND country='United States'
    AND city IS NOT NULL AND state_province IS NOT NULL
),
pairs AS (
  SELECT
    a.city,
    a.state_province,
    (111.045 * DEGREES(ACOS(LEAST(1.0,
      COS(RADIANS(a.latitude)) * COS(RADIANS(b.latitude)) *
      COS(RADIANS(a.longitude) - RADIANS(b.longitude)) +
      SIN(RADIANS(a.latitude)) * SIN(RADIANS(b.latitude))
    )))) AS km
  FROM base a
  JOIN base b
    ON a.city=b.city
   AND a.state_province=b.state_province
   AND a.brewery_id < b.brewery_id
)
SELECT
  city,
  state_province,
  ROUND(MAX(km), 2) AS max_distance_km,
  COUNT(*) AS pair_count
FROM pairs
GROUP BY city, state_province
HAVING pair_count >= 20
ORDER BY max_distance_km DESC
LIMIT 20;

-- 06) City leaders with percentile rank (analytic SQL)
WITH city_counts AS (
  SELECT city, state_province, COUNT(*) AS breweries
  FROM v_breweries_clean
  WHERE country='United States'
    AND city IS NOT NULL AND state_province IS NOT NULL
  GROUP BY city, state_province
)
SELECT
  city, state_province, breweries,
  ROUND(PERCENT_RANK() OVER (ORDER BY breweries), 4) AS pct_rank
FROM city_counts
ORDER BY breweries DESC
LIMIT 25;
