-- sql/04_insights_quality.sql
USE brewery_dw;

-- 10) Data hygiene: suspect phone formats (profiling)
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN phone IS NULL OR TRIM(phone)='' THEN 1 ELSE 0 END) AS missing_phone,
  SUM(CASE WHEN phone REGEXP '^[0-9]{10}$' THEN 1 ELSE 0 END) AS valid_10_digits,
  SUM(CASE WHEN phone IS NOT NULL AND TRIM(phone)<>'' AND phone NOT REGEXP '^[0-9]{10}$' THEN 1 ELSE 0 END) AS invalid_format
FROM v_breweries_clean;

-- Q1) Dimension fragmentation: whitespace variants
SELECT
  country,
  COUNT(*) AS rows_affected
FROM breweries
WHERE country IS NOT NULL AND country <> TRIM(country)
GROUP BY country
ORDER BY rows_affected DESC;

-- Q2) Postal code quality (US ZIP / ZIP+4 coverage)
SELECT
  COUNT(*) AS total_us,
  SUM(CASE WHEN postal_code REGEXP '^[0-9]{5}$' THEN 1 ELSE 0 END) AS zip5,
  SUM(CASE WHEN postal_code REGEXP '^[0-9]{5}-[0-9]{4}$' THEN 1 ELSE 0 END) AS zip9,
  SUM(CASE WHEN postal_code IS NULL OR TRIM(postal_code)='' THEN 1 ELSE 0 END) AS missing,
  SUM(CASE WHEN postal_code IS NOT NULL AND TRIM(postal_code)<>'' AND postal_code NOT REGEXP '^[0-9]{5}(-[0-9]{4})?$' THEN 1 ELSE 0 END) AS invalid
FROM v_breweries_clean
WHERE country='United States';
