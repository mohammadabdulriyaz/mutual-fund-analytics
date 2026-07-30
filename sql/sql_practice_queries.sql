-- ============================================================
-- Bluestock Fintech - Mutual Fund Analytics Capstone
-- Week 1 Deliverable: SQL Practice Queries
-- Dataset: investor_transactions
-- Author: Mohammed Abdul Riyaz
-- ============================================================

-- ------------------------------------------------------------
-- 1. TABLE STRUCTURE
-- ------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS mutual_fund_analytics;
USE mutual_fund_analytics;

CREATE TABLE IF NOT EXISTS investor_transactions (
    investor_id         VARCHAR(20),
    transaction_date    DATE,
    amfi_code           INT,
    transaction_type    VARCHAR(20),
    amount_inr          DECIMAL(15,2),
    state               VARCHAR(50),
    city                VARCHAR(50),
    city_tier           VARCHAR(10),
    age_group           VARCHAR(10),
    gender              VARCHAR(10),
    annual_income_lakh  DECIMAL(10,2),
    payment_mode        VARCHAR(20),
    kyc_status          VARCHAR(20)
);

-- Load data (adjust path as needed)
-- LOAD DATA INFILE '08_investor_transactions.csv'
-- INTO TABLE investor_transactions
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;


-- ------------------------------------------------------------
-- 2. BASIC SELECT & WHERE
-- ------------------------------------------------------------

-- Q1: Get all SIP transactions above 50,000 INR
SELECT investor_id, transaction_date, amount_inr, state, city
FROM investor_transactions
WHERE transaction_type = 'SIP' AND amount_inr > 50000
ORDER BY amount_inr DESC;

-- Q2: Get all transactions with pending KYC status
SELECT investor_id, state, kyc_status, transaction_type, amount_inr
FROM investor_transactions
WHERE kyc_status = 'Pending';


-- ------------------------------------------------------------
-- 3. GROUP BY & AGGREGATE FUNCTIONS
-- ------------------------------------------------------------

-- Q3: Total investment amount by state (Revenue by region)
SELECT state, SUM(amount_inr) AS total_investment, COUNT(*) AS total_transactions
FROM investor_transactions
GROUP BY state
ORDER BY total_investment DESC;

-- Q4: Count of transactions by type (SIP / Lumpsum / Redemption) - Product performance
SELECT transaction_type, COUNT(*) AS transaction_count, SUM(amount_inr) AS total_amount
FROM investor_transactions
GROUP BY transaction_type
ORDER BY transaction_count DESC;

-- Q5: Average investment amount by age group and gender
SELECT age_group, gender, AVG(amount_inr) AS avg_investment
FROM investor_transactions
GROUP BY age_group, gender
ORDER BY age_group, gender;


-- ------------------------------------------------------------
-- 4. HAVING CLAUSE
-- ------------------------------------------------------------

-- Q6: States with total investment greater than 30 crore (300000000 INR)
SELECT state, SUM(amount_inr) AS total_investment
FROM investor_transactions
GROUP BY state
HAVING SUM(amount_inr) > 300000000
ORDER BY total_investment DESC;

-- Q7: Payment modes used in more than 5000 transactions
SELECT payment_mode, COUNT(*) AS usage_count
FROM investor_transactions
GROUP BY payment_mode
HAVING COUNT(*) > 5000
ORDER BY usage_count DESC;


-- ------------------------------------------------------------
-- 5. WINDOW FUNCTIONS
-- ------------------------------------------------------------

-- Q8: Rank investors within each state by total investment amount
SELECT
    investor_id,
    state,
    amount_inr,
    RANK() OVER (PARTITION BY state ORDER BY amount_inr DESC) AS state_rank
FROM investor_transactions;

-- Q9: Running total of investment amount ordered by transaction date
SELECT
    transaction_date,
    amount_inr,
    SUM(amount_inr) OVER (ORDER BY transaction_date) AS running_total
FROM investor_transactions
ORDER BY transaction_date;

-- Q10: Percentage contribution of each transaction type to total investment
SELECT
    transaction_type,
    SUM(amount_inr) AS type_total,
    ROUND(SUM(amount_inr) * 100.0 / SUM(SUM(amount_inr)) OVER (), 2) AS pct_of_total
FROM investor_transactions
GROUP BY transaction_type;


-- ------------------------------------------------------------
-- 6. KYC / DATA QUALITY CHECK QUERIES
-- ------------------------------------------------------------

-- Q11: KYC verification status summary (%)
SELECT
    kyc_status,
    COUNT(*) AS total,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM investor_transactions), 2) AS percentage
FROM investor_transactions
GROUP BY kyc_status;

-- Q12: Top 5 cities by number of investors (distinct investor_id)
SELECT city, COUNT(DISTINCT investor_id) AS unique_investors
FROM investor_transactions
GROUP BY city
ORDER BY unique_investors DESC
LIMIT 5;
