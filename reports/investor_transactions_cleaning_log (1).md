# Investor Transactions — Cleaning Log

Rows loaded: 32778
Exact duplicate rows removed: 0
transaction_type standardised. Distribution:
transaction_type
SIP           19716
Lumpsum        8095
Redemption     4967
Rows with invalid/non-positive amount_inr: 0
Unparseable dates dropped: 0
Dates beyond current date (2026-07-30) flagged as anomalies: 31836 (range 2026-07-31 00:00:00 to 2113-09-28 00:00:00)
kyc_status enum check passed. Values: ['Pending', 'Verified']
Rows with invalid amfi_code: 0

Final row count: 32778 (removed 0 rows total)