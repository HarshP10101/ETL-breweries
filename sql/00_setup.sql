-- sql/00_setup.sql
USE brewery_dw;

-- Always use trimmed “dimension” values for analysis without mutating source
-- (You can still permanently normalize in silver if you want.)
CREATE OR REPLACE VIEW v_breweries_clean AS
SELECT
  brewery_id,
  TRIM(country) AS country,
  TRIM(state_province) AS state_province,
  TRIM(city) AS city,
  TRIM(brewery_type) AS brewery_type,
  TRIM(name) AS name,
  address_1, address_2, address_3,
  postal_code,
  latitude, longitude,
  phone, website_url,
  updated_at, created_at,
  row_hash, etl_loaded_at, etl_updated_at
FROM breweries;
