# etl/run_etl.py
import os
from dotenv import load_dotenv
from etl.extract import extract_all, BASE_URL
from etl.transform import transform_to_silver
from etl.load import make_engine, ensure_schema, load_bronze, upsert_silver, build_gold_mart
from etl.dq import run_dq
from sqlalchemy import text

def main():
    load_dotenv()
    engine = make_engine()
    ensure_schema(engine)
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    print("[DB] connection ok")


    rows = extract_all(per_page=200)  # full load (you’ll add incremental later)
    load_bronze(engine, rows, source_url=f"{BASE_URL}/breweries")

    df = transform_to_silver(rows)
    upsert_silver(engine, df)

    run_dq(engine)
    build_gold_mart(engine)

if __name__ == "__main__":
    main()
