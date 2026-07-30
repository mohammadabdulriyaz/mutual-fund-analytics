"""
Clean investor_transactions.csv
Tasks:
  - standardise transaction_type values (SIP / Lumpsum / Redemption)
  - validate amount > 0
  - fix date formats -> ISO datetime, flag out-of-range anomalies
  - check KYC status enum values (Verified / Pending / Rejected)
"""
import pandas as pd
import numpy as np

RAW_PATH = "data/raw/investor_transactions.csv"
OUT_PATH = "data/processed/investor_transactions_clean.csv"
LOG_PATH = "data/processed/investor_transactions_cleaning_log.md"

VALID_TXN_TYPES = {"sip": "SIP", "lumpsum": "Lumpsum", "redemption": "Redemption"}
VALID_KYC = {"verified", "pending", "rejected"}

log_lines = []

def log(msg):
    print(msg)
    log_lines.append(msg)

df = pd.read_csv(RAW_PATH)
start_rows = len(df)
log(f"# Investor Transactions — Cleaning Log\n")
log(f"Rows loaded: {start_rows}")

# 1. Remove exact duplicate rows
dupes = df.duplicated().sum()
df = df.drop_duplicates()
log(f"Exact duplicate rows removed: {dupes}")

# 2. Standardise transaction_type (case/whitespace normalisation)
df["transaction_type"] = df["transaction_type"].astype(str).str.strip()
mapped = df["transaction_type"].str.lower().map(VALID_TXN_TYPES)
bad_txn = df[mapped.isna()]
if len(bad_txn):
    log(f"WARNING: {len(bad_txn)} rows had unrecognised transaction_type values: "
        f"{bad_txn['transaction_type'].unique().tolist()}")
df["transaction_type"] = mapped.fillna(df["transaction_type"])
log(f"transaction_type standardised. Distribution:\n{df['transaction_type'].value_counts().to_string()}")

# 3. Validate amount_inr > 0
df["amount_inr"] = pd.to_numeric(df["amount_inr"], errors="coerce")
invalid_amt = df[df["amount_inr"].isna() | (df["amount_inr"] <= 0)]
log(f"Rows with invalid/non-positive amount_inr: {len(invalid_amt)}")
df = df[df["amount_inr"] > 0].copy()

# 4. Fix date formats -> proper datetime (date only, ISO 8601)
df["transaction_date"] = pd.to_datetime(df["transaction_date"], errors="coerce")
bad_dates = df["transaction_date"].isna().sum()
log(f"Unparseable dates dropped: {bad_dates}")
df = df[df["transaction_date"].notna()].copy()

TODAY = pd.Timestamp("2026-07-30")
future_anomalies = df[df["transaction_date"] > TODAY]
log(f"Dates beyond current date (2026-07-30) flagged as anomalies: {len(future_anomalies)} "
    f"(range {future_anomalies['transaction_date'].min()} to {future_anomalies['transaction_date'].max()})"
    if len(future_anomalies) else "No future-dated anomalies.")
df["date_anomaly_flag"] = df["transaction_date"] > TODAY
df["transaction_date"] = df["transaction_date"].dt.strftime("%Y-%m-%d")

# 5. Check KYC status enum values
df["kyc_status"] = df["kyc_status"].astype(str).str.strip()
bad_kyc = df[~df["kyc_status"].str.lower().isin(VALID_KYC)]
if len(bad_kyc):
    log(f"WARNING: {len(bad_kyc)} rows had unrecognised kyc_status values: "
        f"{bad_kyc['kyc_status'].unique().tolist()}")
else:
    log(f"kyc_status enum check passed. Values: {sorted(df['kyc_status'].unique().tolist())}")
df["kyc_status"] = df["kyc_status"].str.capitalize()

# 6. Normalise text/categorical whitespace
for col in ["state", "city", "city_tier", "age_group", "gender", "payment_mode", "investor_id"]:
    df[col] = df[col].astype(str).str.strip()

# 7. amfi_code as int, sanity check
df["amfi_code"] = pd.to_numeric(df["amfi_code"], errors="coerce").astype("Int64")
bad_amfi = df["amfi_code"].isna().sum()
log(f"Rows with invalid amfi_code: {bad_amfi}")
df = df[df["amfi_code"].notna()].copy()

# 8. Sort by amfi_code then date (consistent with nav_history convention)
df = df.sort_values(["amfi_code", "transaction_date"]).reset_index(drop=True)

end_rows = len(df)
log(f"\nFinal row count: {end_rows} (removed {start_rows - end_rows} rows total)")

df.to_csv(OUT_PATH, index=False)
with open(LOG_PATH, "w") as f:
    f.write("\n".join(log_lines))

print(f"\nSaved cleaned file to {OUT_PATH}")
