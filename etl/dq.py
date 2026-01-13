# etl/dq.py
from sqlalchemy import text

def run_dq(engine):
    checks = {
        "no_null_primary_key": """
          SELECT COUNT(*) AS bad
          FROM breweries
          WHERE brewery_id IS NULL OR brewery_id = '';
        """,
        "valid_lat_range": """
          SELECT COUNT(*) AS bad
          FROM breweries
          WHERE latitude IS NOT NULL AND (latitude < -90 OR latitude > 90);
        """,
        "valid_lon_range": """
          SELECT COUNT(*) AS bad
          FROM breweries
          WHERE longitude IS NOT NULL AND (longitude < -180 OR longitude > 180);
        """
    }

    failed= False
    with engine.begin() as conn:
        for name, q in checks.items():
            bad = conn.execute(text(q)).scalar()
            status = "PASS" if bad == 0 else "FAIL"
            print(f"[DQ] {name}: {status} (bad={bad})")
            
    if failed:
      raise RuntimeError("DQ checks failed — aborting pipeline")
