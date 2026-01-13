-- sql/05_insights_gold_drift.sql
USE brewery_dw;

-- 08) Type mix shift day-over-day (requires >= 2 snapshot_date values)
WITH ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY country, state_province, brewery_type
      ORDER BY snapshot_date DESC
    ) AS rn
  FROM mart_brewery_counts
),
latest AS (
  SELECT * FROM ranked WHERE rn = 1
),
prev AS (
  SELECT * FROM ranked WHERE rn = 2
)
SELECT
  l.country, l.state_province, l.brewery_type,
  p.brewery_count AS prev_count,
  l.brewery_count AS latest_count,
  (l.brewery_count - p.brewery_count) AS delta
FROM latest l
JOIN prev p
  ON l.country=p.country
 AND l.state_province=p.state_province
 AND l.brewery_type=p.brewery_type
ORDER BY ABS(delta) DESC
LIMIT 30;
