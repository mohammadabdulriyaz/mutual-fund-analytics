-- ============================================================
-- Bluestock MF — SQLite Star Schema
-- Grain: dim_fund (1 row per AMFI scheme), dim_date (1 row per calendar day)
--        fact_nav (1 row per fund per day), fact_transactions (1 row per investor txn)
--        fact_performance (1 row per fund per return period), fact_aum (1 row per fund per month)
-- ============================================================

PRAGMA foreign_keys = ON;

-- ---------------- DIMENSION: FUND ----------------
CREATE TABLE IF NOT EXISTS dim_fund (
    amfi_code       INTEGER PRIMARY KEY,      -- natural key from AMFI
    scheme_name     TEXT,
    fund_house      TEXT,
    category        TEXT,                     -- e.g. Equity, Debt, Hybrid
    sub_category    TEXT,
    expense_ratio   REAL,                     -- % , validated 0.1–2.5
    inception_date  TEXT
);

-- ---------------- DIMENSION: DATE ----------------
CREATE TABLE IF NOT EXISTS dim_date (
    date_key        TEXT PRIMARY KEY,          -- ISO 'YYYY-MM-DD'
    year            INTEGER NOT NULL,
    quarter         INTEGER NOT NULL,
    month           INTEGER NOT NULL,
    month_name      TEXT NOT NULL,
    day             INTEGER NOT NULL,
    day_of_week     TEXT NOT NULL,
    is_weekend      INTEGER NOT NULL,          -- 0/1
    is_holiday      INTEGER DEFAULT 0          -- 0/1, market holiday flag
);

-- ---------------- FACT: NAV HISTORY (one row per fund per day) ----------------
CREATE TABLE IF NOT EXISTS fact_nav (
    nav_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    amfi_code       INTEGER NOT NULL,
    date_key        TEXT NOT NULL,
    nav             REAL NOT NULL CHECK (nav > 0),
    was_forward_filled INTEGER DEFAULT 0,      -- 1 if value carried from prior trading day
    FOREIGN KEY (amfi_code) REFERENCES dim_fund(amfi_code),
    FOREIGN KEY (date_key)  REFERENCES dim_date(date_key),
    UNIQUE (amfi_code, date_key)
);

-- ---------------- FACT: INVESTOR TRANSACTIONS ----------------
CREATE TABLE IF NOT EXISTS fact_transactions (
    transaction_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    investor_id          TEXT NOT NULL,
    date_key             TEXT NOT NULL,
    amfi_code            INTEGER NOT NULL,
    transaction_type      TEXT NOT NULL CHECK (transaction_type IN ('SIP','Lumpsum','Redemption')),
    amount_inr            REAL NOT NULL CHECK (amount_inr > 0),
    state                 TEXT,
    city                  TEXT,
    city_tier             TEXT,
    age_group             TEXT,
    gender                TEXT,
    annual_income_lakh    REAL,
    payment_mode          TEXT,
    kyc_status            TEXT CHECK (kyc_status IN ('Verified','Pending','Rejected')),
    date_anomaly_flag     INTEGER DEFAULT 0,
    FOREIGN KEY (amfi_code) REFERENCES dim_fund(amfi_code),
    FOREIGN KEY (date_key)  REFERENCES dim_date(date_key)
);

-- ---------------- FACT: SCHEME PERFORMANCE ----------------
CREATE TABLE IF NOT EXISTS fact_performance (
    performance_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    amfi_code        INTEGER NOT NULL,
    date_key         TEXT NOT NULL,             -- as-of date for the return figures
    return_1y        REAL,
    return_3y        REAL,
    return_5y        REAL,
    expense_ratio     REAL CHECK (expense_ratio BETWEEN 0.1 AND 2.5),
    is_anomaly        INTEGER DEFAULT 0,         -- flagged if return/expense_ratio out of plausible range
    FOREIGN KEY (amfi_code) REFERENCES dim_fund(amfi_code),
    FOREIGN KEY (date_key)  REFERENCES dim_date(date_key)
);

-- ---------------- FACT: AUM (derived, monthly grain) ----------------
CREATE TABLE IF NOT EXISTS fact_aum (
    aum_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    amfi_code       INTEGER NOT NULL,
    year_month      TEXT NOT NULL,              -- 'YYYY-MM'
    aum_inr         REAL NOT NULL CHECK (aum_inr >= 0),
    FOREIGN KEY (amfi_code) REFERENCES dim_fund(amfi_code),
    UNIQUE (amfi_code, year_month)
);

CREATE INDEX IF NOT EXISTS idx_txn_amfi_date  ON fact_transactions(amfi_code, date_key);
CREATE INDEX IF NOT EXISTS idx_txn_investor   ON fact_transactions(investor_id);
CREATE INDEX IF NOT EXISTS idx_nav_amfi_date  ON fact_nav(amfi_code, date_key);
CREATE INDEX IF NOT EXISTS idx_perf_amfi      ON fact_performance(amfi_code);
