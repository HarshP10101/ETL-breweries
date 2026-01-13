# etl/transform.py
import pandas as pd
import hashlib
from datetime import datetime

def row_hash_for_df(df: pd.DataFrame) -> pd.Series:
    def rh(row):
        vals = []
        for v in row.values:
            if pd.isna(v):
                vals.append("")
            elif isinstance(v, float):
                vals.append(f"{v:.7f}")  # stable for lat/long
            else:
                vals.append(str(v).strip())
        s = "|".join(vals)
        return hashlib.sha256(s.encode("utf-8")).hexdigest()
    return df.apply(rh, axis=1)

def transform_to_silver(rows: list[dict]) -> pd.DataFrame:
    df = pd.DataFrame(rows)

    keep = [
        "id","name","brewery_type","address_1","address_2","address_3",
        "city","state_province","postal_code","country",
        "latitude","longitude","phone","website_url","updated_at","created_at"
    ]
    
    df = df.reindex(columns=keep).rename(columns={"id": "brewery_id"})

    # normalize string columns: trim + collapse internal whitespace
    string_cols = [
        "brewery_id","name","brewery_type","address_1","address_2","address_3",
        "city","state_province","postal_code","country","phone","website_url"
    ]

    for c in string_cols:
        df[c] = (
            df[c]
            .astype("string")
            .str.strip()
            .str.replace(r"\s+", " ", regex=True)
        )

    # numeric conversions
    df["latitude"] = pd.to_numeric(df["latitude"], errors="coerce")
    df["longitude"] = pd.to_numeric(df["longitude"], errors="coerce")

    # set impossible geo values to NaN (later becomes NULL)
    df.loc[(df["latitude"] < -90) | (df["latitude"] > 90), "latitude"] = pd.NA
    df.loc[(df["longitude"] < -180) | (df["longitude"] > 180), "longitude"] = pd.NA

    # timestamps (keep nulls if missing)
    df["updated_at"] = pd.to_datetime(df["updated_at"], errors="coerce")
    df["created_at"] = pd.to_datetime(df["created_at"], errors="coerce")

    # compute row hash for change detection
    hash_cols = [c for c in df.columns if c not in ["updated_at", "created_at"]]
    df["row_hash"] = row_hash_for_df(df[hash_cols])

    now = datetime.utcnow()
    df["etl_loaded_at"] = now
    df["etl_updated_at"] = now

    print(f"[SILVER] rows={len(df)} cols={len(df.columns)} null_lat={(df['latitude'].isna().mean()):.2%}")
    return df
