"""
Load cleaned CSVs into SQLite (bluestock_mf.db) using SQLAlchemy.
Builds dim_date and dim_fund from available data, then loads fact_transactions.
fact_nav / fact_performance / fact_aum are created empty (schema only) until
nav_history.csv and scheme_performance.csv are supplied.
"""
import pandas as pd
import sqlite3

# NOTE: This sandbox has no network access, so the `sqlalchemy` package could not
# be installed. We use Python's built-in `sqlite3` DB-API instead, which pandas
# `.to_sql()` also accepts directly. To use SQLAlchemy on your own machine instead:
#   from sqlalchemy import create_engine, text
#   engine = create_engine("sqlite:///bluestock_mf.db")
#   ... conn = engine.begin() ... df.to_sql(name, conn, ...)
# The rest of this script's logic is otherwise identical.

DB_PATH = "bluestock_mf.db"
conn = sqlite3.connect(DB_PATH)
engine = conn  # kept as `engine` so downstream code reads the same either way

# 1. Apply schema.sql
with open("schema.sql") as f:
    schema_sql = f.read()

cur = conn.cursor()
for stmt in schema_sql.split(";"):
    stmt = stmt.strip()
    if stmt:
        cur.execute(stmt)
conn.commit()

# 2. Load cleaned transactions
txn = pd.read_csv("data/processed/investor_transactions_clean.csv")
src_rows = len(txn)

# 3. Build dim_date from the full span of dates present in transactions
dates = pd.to_datetime(txn["transaction_date"]).sort_values().unique()
dim_date = pd.DataFrame({"date_key": pd.to_datetime(dates)})
dim_date["year"] = dim_date["date_key"].dt.year
dim_date["quarter"] = dim_date["date_key"].dt.quarter
dim_date["month"] = dim_date["date_key"].dt.month
dim_date["month_name"] = dim_date["date_key"].dt.month_name()
dim_date["day"] = dim_date["date_key"].dt.day
dim_date["day_of_week"] = dim_date["date_key"].dt.day_name()
dim_date["is_weekend"] = dim_date["date_key"].dt.dayofweek.isin([5, 6]).astype(int)
dim_date["is_holiday"] = 0
dim_date["date_key"] = dim_date["date_key"].dt.strftime("%Y-%m-%d")

# 4. Build dim_fund (only amfi_code known; other attrs null until scheme master data supplied)
dim_fund = pd.DataFrame({"amfi_code": sorted(txn["amfi_code"].unique())})
for col in ["scheme_name", "fund_house", "category", "sub_category", "expense_ratio", "inception_date"]:
    dim_fund[col] = None

# 5. Prepare fact_transactions
fact_txn = txn.rename(columns={"transaction_date": "date_key"})[[
    "investor_id", "date_key", "amfi_code", "transaction_type", "amount_inr",
    "state", "city", "city_tier", "age_group", "gender", "annual_income_lakh",
    "payment_mode", "kyc_status", "date_anomaly_flag"
]]

dim_date.to_sql("dim_date", conn, if_exists="append", index=False)
dim_fund.to_sql("dim_fund", conn, if_exists="append", index=False)
fact_txn.to_sql("fact_transactions", conn, if_exists="append", index=False)
conn.commit()

# 6. Verify row counts
loaded = cur.execute("SELECT COUNT(*) FROM fact_transactions").fetchone()[0]
n_dim_date = cur.execute("SELECT COUNT(*) FROM dim_date").fetchone()[0]
n_dim_fund = cur.execute("SELECT COUNT(*) FROM dim_fund").fetchone()[0]

print(f"Source cleaned CSV rows : {src_rows}")
print(f"fact_transactions rows  : {loaded}  {'OK - matches source' if loaded == src_rows else 'MISMATCH'}")
print(f"dim_date rows           : {n_dim_date}")
print(f"dim_fund rows           : {n_dim_fund} (distinct amfi_codes seen in transactions)")
print("\nNOTE: fact_nav, fact_performance, fact_aum tables created (schema only, 0 rows) —")
print("      pending nav_history.csv and scheme_performance.csv.")
