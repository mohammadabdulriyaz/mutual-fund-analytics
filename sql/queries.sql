-- ============================================================
-- Bluestock MF — Analytical Queries
-- Queries 1,3,5,6,7 run fully today (transactions data loaded).
-- Queries 2,4,8,9,10 reference fact_nav / fact_performance / fact_aum,
-- which are schema-ready but empty until nav_history.csv and
-- scheme_performance.csv are supplied — they will return 0 rows for now.
-- ============================================================

-- 1. Top 5 funds by total transaction value (proxy for AUM inflow until fact_aum is populated)
SELECT f.amfi_code,
       SUM(t.amount_inr) AS total_txn_value
FROM fact_transactions t
JOIN dim_fund f ON f.amfi_code = t.amfi_code
GROUP BY f.amfi_code
ORDER BY total_txn_value DESC
LIMIT 5;

-- 2. Top 5 funds by AUM (once fact_aum is loaded)
SELECT f.amfi_code,
       a.year_month,
       a.aum_inr
FROM fact_aum a
JOIN dim_fund f ON f.amfi_code = a.amfi_code
WHERE a.year_month = (SELECT MAX(year_month) FROM fact_aum)
ORDER BY a.aum_inr DESC
LIMIT 5;

-- 3. Average NAV per month per fund (once fact_nav is loaded)
SELECT n.amfi_code,
       strftime('%Y-%m', n.date_key) AS year_month,
       ROUND(AVG(n.nav), 4) AS avg_nav
FROM fact_nav n
GROUP BY n.amfi_code, year_month
ORDER BY n.amfi_code, year_month;

-- 4. SIP transaction value — Year-over-Year growth
WITH sip_yearly AS (
    SELECT strftime('%Y', date_key) AS yr,
           SUM(amount_inr) AS sip_total
    FROM fact_transactions
    WHERE transaction_type = 'SIP'
    GROUP BY yr
)
SELECT yr,
       sip_total,
       LAG(sip_total) OVER (ORDER BY yr) AS prev_year_total,
       ROUND(
         100.0 * (sip_total - LAG(sip_total) OVER (ORDER BY yr))
         / NULLIF(LAG(sip_total) OVER (ORDER BY yr), 0), 2
       ) AS yoy_growth_pct
FROM sip_yearly
ORDER BY yr;

-- 5. Transactions by state
SELECT state,
       COUNT(*) AS txn_count,
       SUM(amount_inr) AS total_amount
FROM fact_transactions
GROUP BY state
ORDER BY total_amount DESC;

-- 6. Funds with expense_ratio < 1% (once fact_performance is loaded)
SELECT f.amfi_code, p.expense_ratio
FROM fact_performance p
JOIN dim_fund f ON f.amfi_code = p.amfi_code
WHERE p.expense_ratio < 1.0
ORDER BY p.expense_ratio;

-- 7. Transaction type mix (count and value share) by city tier
SELECT city_tier,
       transaction_type,
       COUNT(*) AS txn_count,
       SUM(amount_inr) AS total_amount,
       ROUND(100.0 * SUM(amount_inr) / SUM(SUM(amount_inr)) OVER (PARTITION BY city_tier), 2) AS pct_of_tier_value
FROM fact_transactions
GROUP BY city_tier, transaction_type
ORDER BY city_tier, total_amount DESC;

-- 8. Top 5 funds by 1-year return (once fact_performance is loaded)
SELECT f.amfi_code, p.return_1y
FROM fact_performance p
JOIN dim_fund f ON f.amfi_code = p.amfi_code
ORDER BY p.return_1y DESC
LIMIT 5;

-- 9. Investor KYC funnel — Verified vs Pending, by age group
SELECT age_group,
       kyc_status,
       COUNT(*) AS investor_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY age_group), 2) AS pct_within_age_group
FROM fact_transactions
GROUP BY age_group, kyc_status
ORDER BY age_group, kyc_status;

-- 10. Average ticket size by payment mode and transaction type
SELECT payment_mode,
       transaction_type,
       COUNT(*) AS txn_count,
       ROUND(AVG(amount_inr), 2) AS avg_ticket_size
FROM fact_transactions
GROUP BY payment_mode, transaction_type
ORDER BY payment_mode, transaction_type;
