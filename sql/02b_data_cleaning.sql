-- BADMINTON ANALYTICS | 02b — Staging date standardization & checks
-- SOURCE: 02_original_sql_workflow.sql (original lines 91–110).
-- PREREQUISITE: Run 02a, then import the curated match data into stg_matches.
-- Run ONLY on a fresh staging table that does not already have match_date.
-- The raw source used DD-MM-YYYY strings and was prepared prior to its database import.
-- This script covers only the date conversion present in the saved SQL history.

-- Inspect date range and source date strings BEFORE conversion.
SELECT
    MIN(TO_DATE("date", 'DD-MM-YYYY')) AS earliest_date,
    MAX(TO_DATE("date", 'DD-MM-YYYY')) AS latest_date,
    COUNT(*) FILTER (
        WHERE TO_CHAR(TO_DATE("date", 'DD-MM-YYYY'), 'DD-MM-YYYY') <> "date"
    ) AS invalid_date_format
FROM stg_matches;

-- Add the typed date used by the warehouse model.
ALTER TABLE stg_matches
ADD COLUMN match_date DATE;

UPDATE stg_matches
SET match_date = TO_DATE("date", 'DD-MM-YYYY');

-- Verify the date conversion and row count.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE match_date IS NULL) AS null_match_dates,
    MIN(match_date) AS earliest_date,
    MAX(match_date) AS latest_date
FROM stg_matches;

-- Expected curated staging count: 10,444. Check against the imported source file.
-- Dates should be within 2018-01-01 through 2025-12-31 and should have no NULLs.
-- Review abnormal values in the source file before proceeding to the warehouse load.
