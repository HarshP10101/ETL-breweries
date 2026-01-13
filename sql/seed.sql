-- seed.sql
-- Purpose:
-- 1) Create helper tables (optional) for auditing
-- 2) Create views that make insights + reporting easier

USE brewery_dw;

-- -------------------------
-- OPTIONAL: ETL run logging
-- -------------------------
CREATE TABLE IF NOT EXISTS etl_runs (
  run_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  started_at DATETIME NOT NULL,
  finished_at DATETIME NULL,
  status VARCHAR(16) NOT NULL,         -- RUNNING / SUCCESS / FAIL
  extracted_rows INT NULL,
  bronze_attempted INT NULL,
  silver_upserted INT NULL,
  error_message TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -------------------------
-- Views for analytics
-- -------------------------

-- 1) Latest snapshot mart (easy for Power BI / reporting)
CREATE OR REPLACE VIEW v_mart_latest_brewery_counts AS
SELECT m.*
FROM mart_brewery_counts m
JOIN (
  SELECT MAX(snapshot_date) AS max_date
  FROM mart_brewery_counts
) x
  ON m.snapshot_date = x.max_date;

-- 2) Geo completeness by country/state/type (data quality insight)
CREATE OR REPLACE VIEW v_geo_completeness AS
SELECT
  country,
  state_province,
  brewery_type,
  COUNT(*) AS total_breweries,
  SUM(CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 ELSE 0 END) AS geo_present,
  ROUND(100 * SUM(CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS geo_pct
FROM breweries
GROUP BY country, state_province, brewery_type;

-- 3) Top cities by brewery count (with filters to avoid NULLs)
CREATE OR REPLACE VIEW v_top_cities AS
SELECT
  country,
  state_province,
  city,
  COUNT(*) AS brewery_count
FROM breweries
WHERE country IS NOT NULL AND state_province IS NOT NULL AND city IS NOT NULL
GROUP BY country, state_province, city
ORDER BY brewery_count DESC;

-- 4) Brewery type mix by state (good for “distribution shift” insight)
CREATE OR REPLACE VIEW v_state_type_mix AS
SELECT
  country,
  state_province,
  brewery_type,
  COUNT(*) AS type_count,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY country, state_province), 2) AS type_pct
FROM breweries
WHERE country IS NOT NULL AND state_province IS NOT NULL AND brewery_type IS NOT NULL
GROUP BY country, state_province, brewery_type;

-- 5) Duplicate-name scan within a city/state (potential entity matching issue)
CREATE OR REPLACE VIEW v_possible_duplicates AS
SELECT
  country,
  state_province,
  city,
  name,
  COUNT(*) AS occurrences
FROM breweries
WHERE country IS NOT NULL AND state_province IS NOT NULL AND city IS NOT NULL AND name IS NOT NULL
GROUP BY country, state_province, city, name
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- 6) Country normalization check (leading/trailing whitespace)
CREATE OR REPLACE VIEW v_country_whitespace_issues AS
SELECT
  country,
  COUNT(*) AS rows_affected
FROM breweries
WHERE country IS NOT NULL AND country <> TRIM(country)
GROUP BY country
ORDER BY rows_affected DESC;
