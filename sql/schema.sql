-- schema.sql
-- Database: brewery_dw
-- Purpose: Create Bronze/Silver/Gold tables + indexes for the Open Brewery DB ETL

CREATE DATABASE IF NOT EXISTS brewery_dw;
USE brewery_dw;

-- =========================
-- BRONZE: Raw API payloads
-- =========================
CREATE TABLE IF NOT EXISTS breweries_raw (
  raw_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  brewery_id VARCHAR(64) NOT NULL,
  payload JSON NOT NULL,
  fetched_at DATETIME NOT NULL,
  source_url VARCHAR(255) NOT NULL,
  payload_hash CHAR(64) NOT NULL,

  UNIQUE KEY uq_breweries_raw (brewery_id, payload_hash),
  INDEX idx_breweries_raw_brewery_id (brewery_id),
  INDEX idx_breweries_raw_fetched_at (fetched_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- SILVER: Clean, query-ready
-- =========================
CREATE TABLE IF NOT EXISTS breweries (
  brewery_id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(255),
  brewery_type VARCHAR(64),
  address_1 VARCHAR(255),
  address_2 VARCHAR(255),
  address_3 VARCHAR(255),
  city VARCHAR(128),
  state_province VARCHAR(128),
  postal_code VARCHAR(32),
  country VARCHAR(128),
  latitude DECIMAL(10,7),
  longitude DECIMAL(10,7),
  phone VARCHAR(32),
  website_url VARCHAR(255),
  updated_at DATETIME,
  created_at DATETIME,

  row_hash CHAR(64) NOT NULL,
  etl_loaded_at DATETIME NOT NULL,
  etl_updated_at DATETIME NOT NULL,

  INDEX idx_breweries_geo_type (country, state_province, brewery_type),
  INDEX idx_breweries_city (country, state_province, city),
  INDEX idx_breweries_type (brewery_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- GOLD: Reporting Mart
-- =========================
CREATE TABLE IF NOT EXISTS mart_brewery_counts (
  snapshot_date DATE NOT NULL,
  country VARCHAR(128) NOT NULL,
  state_province VARCHAR(128) NOT NULL,
  brewery_type VARCHAR(64) NOT NULL,
  brewery_count INT NOT NULL,

  PRIMARY KEY (snapshot_date, country, state_province, brewery_type),
  INDEX idx_mart_state (country, state_province),
  INDEX idx_mart_type (brewery_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
