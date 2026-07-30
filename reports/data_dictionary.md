# Bluestock MF — Data Dictionary

**Database:** `bluestock_mf.db` (SQLite)
**Schema type:** Star schema — `dim_fund`, `dim_date` (dimensions) around `fact_nav`, `fact_transactions`, `fact_performance`, `fact_aum` (facts)
**Last updated:** 2026-07-30
**Status:** `fact_transactions` is fully loaded and verified (32,778 / 32,778 rows). `fact_nav`, `fact_performance`, and `fact_aum` are schema-ready but empty — pending `nav_history.csv` and `scheme_performance.csv`.

---

## dim_fund
One row per mutual fund scheme (AMFI code).

| Column | Type | Description | Source |
|---|---|---|---|
| amfi_code | INTEGER (PK) | AMFI scheme code, unique fund identifier | investor_transactions.csv, nav_history.csv |
| scheme_name | TEXT | Full scheme name | scheme_performance.csv (not yet loaded) |
| fund_house | TEXT | AMC / fund house name | scheme_performance.csv (not yet loaded) |
| category | TEXT | Broad category (Equity/Debt/Hybrid) | scheme_performance.csv (not yet loaded) |
| sub_category | TEXT | Scheme sub-category | scheme_performance.csv (not yet loaded) |
| expense_ratio | REAL | Fund expense ratio (%), valid range 0.1–2.5 | scheme_performance.csv (not yet loaded) |
| inception_date | TEXT (ISO date) | Fund launch date | scheme_performance.csv (not yet loaded) |

*Currently populated only with the 40 distinct `amfi_code` values observed in transactions; descriptive attributes are NULL until scheme master data is loaded.*

## dim_date
One row per calendar date appearing in the fact tables.

| Column | Type | Description |
|---|---|---|
| date_key | TEXT (PK, ISO 'YYYY-MM-DD') | Calendar date |
| year | INTEGER | Calendar year |
| quarter | INTEGER | 1–4 |
| month | INTEGER | 1–12 |
| month_name | TEXT | e.g. "January" |
| day | INTEGER | Day of month |
| day_of_week | TEXT | e.g. "Monday" |
| is_weekend | INTEGER (0/1) | 1 if Saturday/Sunday |
| is_holiday | INTEGER (0/1) | Market holiday flag (not yet populated — needs a holiday calendar source) |

## fact_nav — *(schema only, pending nav_history.csv)*
Grain: one row per fund per trading day.

| Column | Type | Description | Business rule |
|---|---|---|---|
| nav_id | INTEGER (PK) | Surrogate key | Auto-increment |
| amfi_code | INTEGER (FK → dim_fund) | Fund identifier | |
| date_key | TEXT (FK → dim_date) | NAV date | |
| nav | REAL | Net Asset Value per unit (₹) | Must be > 0 |
| was_forward_filled | INTEGER (0/1) | 1 if this value was carried forward from the prior trading day (holiday/weekend fill) | |

## fact_transactions
Grain: one row per investor transaction. **Source: `investor_transactions.csv`.**

| Column | Type | Description | Business rule |
|---|---|---|---|
| transaction_id | INTEGER (PK) | Surrogate key | Auto-increment |
| investor_id | TEXT | Unique investor identifier | e.g. INV003054 |
| date_key | TEXT (FK → dim_date) | Transaction date | Parsed to ISO date |
| amfi_code | INTEGER (FK → dim_fund) | Fund the transaction was placed against | |
| transaction_type | TEXT | One of `SIP`, `Lumpsum`, `Redemption` | Standardised/validated enum |
| amount_inr | REAL | Transaction amount in ₹ | Must be > 0 |
| state | TEXT | Investor's state | |
| city | TEXT | Investor's city | |
| city_tier | TEXT | `T30` (Top 30 cities) or `B30` (Beyond Top 30) | AMFI classification |
| age_group | TEXT | Investor age bracket | 18-25 / 26-35 / 36-45 / 46-55 / 56+ |
| gender | TEXT | Investor gender | |
| annual_income_lakh | REAL | Self-declared annual income (₹ lakh) | |
| payment_mode | TEXT | UPI / Net Banking / Cheque / Mandate | |
| kyc_status | TEXT | `Verified`, `Pending`, or `Rejected` | Validated enum |
| date_anomaly_flag | INTEGER (0/1) | 1 if `date_key` falls after 2026-07-30 (current date). Source file contains a sequential-date generation artifact producing dates as far out as 2113; flagged rather than deleted to preserve all 32,778 records. | See cleaning log |

**Row count check:** raw CSV = 32,778 rows → cleaned/loaded = 32,778 rows (0 dropped; 0 duplicates, 0 invalid amounts, 0 unparseable dates, 0 invalid KYC values found).

## fact_performance — *(schema only, pending scheme_performance.csv)*
Grain: one row per fund per as-of date.

| Column | Type | Description | Business rule |
|---|---|---|---|
| performance_id | INTEGER (PK) | Surrogate key | Auto-increment |
| amfi_code | INTEGER (FK → dim_fund) | Fund identifier | |
| date_key | TEXT (FK → dim_date) | As-of date for return figures | |
| return_1y | REAL | 1-year trailing return (%) | |
| return_3y | REAL | 3-year trailing return (%) | |
| return_5y | REAL | 5-year trailing return (%) | |
| expense_ratio | REAL | Expense ratio (%) | Valid range 0.1–2.5 |
| is_anomaly | INTEGER (0/1) | Flag for non-numeric/out-of-range values found during cleaning | |

## fact_aum — *(schema only, pending source data / derivation)*
Grain: one row per fund per month.

| Column | Type | Description |
|---|---|---|
| aum_id | INTEGER (PK) | Surrogate key |
| amfi_code | INTEGER (FK → dim_fund) | Fund identifier |
| year_month | TEXT ('YYYY-MM') | Month |
| aum_inr | REAL | Assets Under Management (₹) |

---

## Known data quality notes
1. **Future-dated transactions:** ~97% of rows in `investor_transactions.csv` have dates after 2026-07-30 (up to 2113), consistent with a sequential day-increment pattern starting 2024-01-01 rather than a real-world date distribution. Flagged via `date_anomaly_flag`, not deleted — confirm with source system whether this is test/synthetic data before using dates for time-series analysis as-is.
2. **Missing source files:** `nav_history.csv` and `scheme_performance.csv` were not provided in this run, so `fact_nav`, `fact_performance`, and part of `dim_fund` (scheme_name, fund_house, category, expense_ratio, etc.) could not be loaded or validated.
