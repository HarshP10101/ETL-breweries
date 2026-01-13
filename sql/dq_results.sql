-- dq_results.sql
-- Purpose:
-- Log DQ checks into tables so you have an audit trail (senior-level feature)

USE brewery_dw;

-- A catalog of checks (what exists + why)
CREATE TABLE IF NOT EXISTS dq_checks (
  check_name VARCHAR(64) PRIMARY KEY,
  description VARCHAR(255) NOT NULL,
  severity VARCHAR(16) NOT NULL          -- WARN / ERROR
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Results of running checks (every run)
CREATE TABLE IF NOT EXISTS dq_results (
  result_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  run_at DATETIME NOT NULL,
  check_name VARCHAR(64) NOT NULL,
  status VARCHAR(8) NOT NULL,            -- PASS / FAIL
  bad_count INT NOT NULL,
  sample_query TEXT NULL,

  INDEX idx_dq_results_run_at (run_at),
  INDEX idx_dq_results_check (check_name),
  CONSTRAINT fk_dq_check
    FOREIGN KEY (check_name) REFERENCES dq_checks(check_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed the checks catalog (safe to re-run)
INSERT INTO dq_checks (check_name, description, severity) VALUES
('no_null_primary_key', 'brewery_id must be present in silver table', 'ERROR'),
('valid_lat_range', 'latitude must be within [-90, 90] if present', 'ERROR'),
('valid_lon_range', 'longitude must be within [-180, 180] if present', 'ERROR'),
('country_has_whitespace', 'country should not have leading/trailing whitespace', 'WARN')
ON DUPLICATE KEY UPDATE
  description = VALUES(description),
  severity = VALUES(severity);
