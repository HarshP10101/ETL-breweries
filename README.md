# 🍺 Open Brewery DB Production-Grade ETL (REST to MySQL)

A real world, production style data engineering project that ingests data from a public REST API, applies data quality controls, models bronze, silver, and gold layers, and generates advanced analytical insights using SQL.

This project is intentionally designed to go beyond toy ETL examples and demonstrate how real data systems are built, validated, and analyzed.

---

## 🔧 Tech Stack

* Python 3.11
* REST API (Open Brewery DB)
* MySQL 8 (Dockerized)
* SQLAlchemy and PyMySQL
* Pandas
* Advanced SQL (CTEs, window functions, entropy, HHI, geo math)
* Git and GitHub

---

## 🧱 Architecture Overview

```
REST API
   |
[ EXTRACT ]
   |
[ BRONZE ]   Raw JSON payloads
   |
[ TRANSFORM ]
   |
[ SILVER ]   Clean canonical tables
   |
[ GOLD ]     Analytical marts
```

This mirrors real data platform patterns used in modern analytics stacks such as Databricks, Snowflake, BigQuery, and Microsoft Fabric.

---

## 🟤 Bronze Layer (Raw and Immutable)

**Purpose:** Preserve the source of truth exactly as received.

Key characteristics:

* Full API payload stored as JSON
* Deduplication using `(brewery_id, payload_hash)`
* Supports replay, audits, and debugging
* No transformations applied

```sql
breweries_raw
  raw_id
  brewery_id
  payload
  payload_hash
  fetched_at
  source_url
```

Why store raw JSON in SQL
Because production systems often ingest semi structured data and engineers must handle it safely.

---

## ⚪ Silver Layer (Clean and Canonical)

**Purpose:** Provide a single trusted representation of each brewery.

Key features:

* Strong typing for latitude, longitude, and timestamps
* Canonical string normalization using trimming and coercion
* Invalid geo values safely converted to NULL
* Hash based change detection using `row_hash`
* Idempotent upsert logic

```sql
breweries
  brewery_id (primary key)
  brewery attributes
  geo attributes
  row_hash
  etl_loaded_at
  etl_updated_at
```

Why hashing instead of relying on timestamps
APIs often provide unreliable or missing update timestamps. Hashing guarantees accurate change detection.

---

## 🟡 Gold Layer (Analytics Ready)

**Purpose:** Fast, query friendly datasets for reporting and insights.

* Daily snapshotting
* Dimensional aggregation
* Optimized for BI tools

```sql
mart_brewery_counts
  snapshot_date
  country
  state_province
  brewery_type
  brewery_count
```

---

## ✅ Data Quality Framework

This project does not assume incoming data is clean.

Every pipeline run executes and logs data quality checks:

* Primary key integrity
* Latitude range validation
* Longitude range validation
* Dimension hygiene such as whitespace issues

Results are persisted for auditability.

```sql
dq_results
  run_at
  check_name
  status
  bad_count
  sample_query
```

This enables historical tracking, auditing, and production readiness.

---

## 📊 Advanced SQL Insights

Using SQL to find deeper and valuable insights 

Examples include:

1. Brewery density leaders normalized by city coverage
2. Market fragmentation index using HHI
3. Over represented brewery types using lift vs national baseline
4. Geo coverage score as a data completeness metric
5. Geo outlier detection using pairwise distance calculations
6. City percentile rankings using window functions
7. Diversity score using Shannon entropy
8. Gold layer snapshot drift analysis
9. Top brewery type dominance per state
10. Data hygiene profiling for phone numbers and postal codes

All queries live under:

```
sql/
  01_insights_geography.sql
  02_insights_concentration.sql
  03_insights_distribution.sql
  04_insights_quality.sql
  05_insights_gold_drift.sql
```

---

## 🐳 Infrastructure (Docker)

MySQL runs fully containerized.

```bash
docker run --name brewery-mysql \
  --env-file .env
  -p 3306:3306 \
  -d mysql:8
```

This ensures reproducibility and environment isolation.

---

## ▶️ How to Run

```bash
pip install -r requirements.txt
python -m etl.run_etl
```

The pipeline is idempotent and safe to re run.

---

## 💡 Why This Project Exists

Most ETL projects online:

* skip data quality
* ignore change detection
* flatten everything
* stop at simple counts

This project was built to reflect how data engineering actually works in production, including tradeoffs, safeguards, and analytical rigor.

---

## 🚀 Planned Extensions

* Incremental ingestion using fetched timestamps
* Slowly changing dimensions (Type 2)
* Power BI semantic model
* Orchestration using Airflow or Prefect
* Expanded data quality rules

---

## About the Author

Built by **Harsh Patel**
Data Analyst and Analytics Engineer with strong data engineering foundations.

This repository reflects how data systems are designed end to end, not just code that runs once.
