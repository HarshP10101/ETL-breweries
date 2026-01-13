# etl/load.py
import os
import json
import hashlib
import pandas as pd
from datetime import datetime

from sqlalchemy import create_engine, text


def make_engine():
    host = os.getenv("MYSQL_HOST", "localhost")
    port = os.getenv("MYSQL_PORT", "3306")
    db = os.getenv("MYSQL_DB", "brewery_dw")
    user = os.getenv("MYSQL_USER", "root")
    pw = os.getenv("MYSQL_PASSWORD", "")

    return create_engine(
        f"mysql+pymysql://{user}:{pw}@{host}:{port}/{db}?charset=utf8mb4",
        pool_pre_ping=True
    )


def sha256_str(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()

def ensure_schema(engine):
    ddl_statements = [
        """
        CREATE TABLE IF NOT EXISTS breweries_raw (
          raw_id BIGINT AUTO_INCREMENT PRIMARY KEY,
          brewery_id VARCHAR(64) NOT NULL,
          payload JSON NOT NULL,
          fetched_at DATETIME NOT NULL,
          source_url VARCHAR(255) NOT NULL,
          payload_hash CHAR(64) NOT NULL,
          UNIQUE KEY uq_breweries_raw (brewery_id, payload_hash)
        )
        """,
        """
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
          etl_updated_at DATETIME NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS mart_brewery_counts (
          snapshot_date DATE NOT NULL,
          country VARCHAR(128),
          state_province VARCHAR(128),
          brewery_type VARCHAR(64),
          brewery_count INT NOT NULL,
          PRIMARY KEY (snapshot_date, country, state_province, brewery_type)
        )
        """
    ]

    with engine.begin() as conn:
        for stmt in ddl_statements:
            conn.execute(text(stmt))
        # create index safely (won't fail on reruns)
        try:
            conn.execute(text("""
                CREATE INDEX idx_breweries_geo_type
                ON breweries(country, state_province, brewery_type)
            """))
        except Exception:
            pass
    print("[DB] schema ensured (tables exist + indexes)")

def load_bronze(engine, rows: list[dict], source_url: str):
    now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")

    sql = text("""
        INSERT IGNORE INTO breweries_raw
          (brewery_id, payload, fetched_at, source_url, payload_hash)
        VALUES
          (:brewery_id, CAST(:payload AS JSON), :fetched_at, :source_url, :payload_hash)
    """)

    attempted = 0
    with engine.begin() as conn:
        for row in rows:
            brewery_id = str(row.get("id"))
            payload_str = json.dumps(row, ensure_ascii=False, sort_keys=True)
            payload_hash = sha256_str(payload_str)

            conn.execute(sql, {
                "brewery_id": brewery_id,
                "payload": payload_str,
                "fetched_at": now,
                "source_url": source_url,
                "payload_hash": payload_hash
            })
            attempted += 1

    print(f"[BRONZE] attempted_inserts={attempted} (dedupe via INSERT IGNORE)")


def upsert_silver(engine, df):
    sql = text("""
    INSERT INTO breweries (
      brewery_id, name, brewery_type, address_1, address_2, address_3,
      city, state_province, postal_code, country, latitude, longitude,
      phone, website_url, updated_at, created_at, row_hash, etl_loaded_at, etl_updated_at
    )
    VALUES (
      :brewery_id, :name, :brewery_type, :address_1, :address_2, :address_3,
      :city, :state_province, :postal_code, :country, :latitude, :longitude,
      :phone, :website_url, :updated_at, :created_at, :row_hash, :etl_loaded_at, :etl_updated_at
    )
    ON DUPLICATE KEY UPDATE
      name = IF(row_hash <> VALUES(row_hash), VALUES(name), name),
      brewery_type = IF(row_hash <> VALUES(row_hash), VALUES(brewery_type), brewery_type),
      address_1 = IF(row_hash <> VALUES(row_hash), VALUES(address_1), address_1),
      address_2 = IF(row_hash <> VALUES(row_hash), VALUES(address_2), address_2),
      address_3 = IF(row_hash <> VALUES(row_hash), VALUES(address_3), address_3),
      city = IF(row_hash <> VALUES(row_hash), VALUES(city), city),
      state_province = IF(row_hash <> VALUES(row_hash), VALUES(state_province), state_province),
      postal_code = IF(row_hash <> VALUES(row_hash), VALUES(postal_code), postal_code),
      country = IF(row_hash <> VALUES(row_hash), VALUES(country), country),
      latitude = IF(row_hash <> VALUES(row_hash), VALUES(latitude), latitude),
      longitude = IF(row_hash <> VALUES(row_hash), VALUES(longitude), longitude),
      phone = IF(row_hash <> VALUES(row_hash), VALUES(phone), phone),
      website_url = IF(row_hash <> VALUES(row_hash), VALUES(website_url), website_url),
      updated_at = IF(row_hash <> VALUES(row_hash), VALUES(updated_at), updated_at),
      created_at = IF(row_hash <> VALUES(row_hash), VALUES(created_at), created_at),
      row_hash = VALUES(row_hash),
      etl_updated_at = IF(row_hash <> VALUES(row_hash), VALUES(etl_updated_at), etl_updated_at);
    """)
    ##
    rows = df.to_dict(orient="records")
    with engine.begin() as conn:
        for r in rows:
            # updated_at
            if r.get("updated_at") is not None and not pd.isna(r["updated_at"]):
                r["updated_at"] = r["updated_at"].to_pydatetime()
            else:
                r["updated_at"] = None

            # created_at
            if r.get("created_at") is not None and not pd.isna(r["created_at"]):
                r["created_at"] = r["created_at"].to_pydatetime()
            else:
                r["created_at"] = None

            # ETL timestamps
            if r.get("etl_loaded_at") is not None and hasattr(r["etl_loaded_at"], "to_pydatetime"):
                r["etl_loaded_at"] = r["etl_loaded_at"].to_pydatetime()

            if r.get("etl_updated_at") is not None and hasattr(r["etl_updated_at"], "to_pydatetime"):
                r["etl_updated_at"] = r["etl_updated_at"].to_pydatetime()

            # convert NaN floats to None (MySQL NULL)
            if "latitude" in r and pd.isna(r["latitude"]):
                r["latitude"] = None
            if "longitude" in r and pd.isna(r["longitude"]):
                r["longitude"] = None
                
            conn.execute(sql, r)
            
            



    print(f"[SILVER LOAD] upserted={len(rows)}")


def build_gold_mart(engine):
    sql = text("""
    INSERT INTO mart_brewery_counts (snapshot_date, country, state_province, brewery_type, brewery_count)
    SELECT
      CURDATE() AS snapshot_date,
      country,
      state_province,
      brewery_type,
      COUNT(*) AS brewery_count
    FROM breweries
    GROUP BY country, state_province, brewery_type
    ON DUPLICATE KEY UPDATE
      brewery_count = VALUES(brewery_count);
    """)

    with engine.begin() as conn:
        conn.execute(sql)

    print("[GOLD] mart_brewery_counts refreshed for today")
