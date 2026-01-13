# etl/extract.py
import requests
from tenacity import retry, stop_after_attempt, wait_exponential

BASE_URL = "https://api.openbrewerydb.org/v1"

@retry(stop=stop_after_attempt(5), wait=wait_exponential(multiplier=1, min=1, max=20))
def fetch_page(page: int, per_page: int = 200) -> list[dict]:
    url = f"{BASE_URL}/breweries"
    params = {"page": page, "per_page": per_page}
    r = requests.get(url, params=params, timeout=30)
    r.raise_for_status()
    return r.json()

def extract_all(per_page: int = 200, max_pages: int | None = None) -> list[dict]:
    all_rows = []
    page = 1

    while True:
        if max_pages and page > max_pages:
            break

        rows = fetch_page(page=page, per_page=per_page)
        print(f"[EXTRACT] page={page} rows={len(rows)}")

        if not rows:
            break

        all_rows.extend(rows)
        page += 1

    print(f"[EXTRACT] total_rows={len(all_rows)}")
    return all_rows

