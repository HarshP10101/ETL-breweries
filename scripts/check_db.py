from sqlalchemy import create_engine, text
from dotenv import load_dotenv
import os

load_dotenv()

engine = create_engine(
    f"mysql+pymysql://{os.getenv('MYSQL_USER')}:{os.getenv('MYSQL_PASSWORD')}@"
    f"{os.getenv('MYSQL_HOST')}:{os.getenv('MYSQL_PORT')}/{os.getenv('MYSQL_DB')}"
)

with engine.connect() as conn:
    print("Database:", conn.execute(text("SELECT DATABASE()")).scalar())
    print("Breweries:", conn.execute(text("SELECT COUNT(*) FROM breweries")).scalar())
    print("Raw rows:", conn.execute(text("SELECT COUNT(*) FROM breweries_raw")).scalar())
