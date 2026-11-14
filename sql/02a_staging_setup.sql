-- BADMINTON ANALYTICS | 02a — Staging table setup
-- SOURCE: 02_original_sql_workflow.sql (final staging definition, original lines 70–83).
-- Run ONLY in a new, empty database. Do not run against your working badminton_analytics DB.
--
-- NEXT: Import your already-curated 2018–2025 match file into public.stg_matches.
-- Expected CSV headings: date, discipline, tournament, tier, round, host_location,
-- team1, team2, winner, score, team1_at_home, team2_at_home.
-- This uploaded SQL workflow did NOT contain the original source-file preparation steps.
-- Do not treat this script as a replacement for the missing CSV/Excel cleaning work.

CREATE TABLE stg_matches (
    "date" VARCHAR(20),
    discipline VARCHAR(10),
    tournament VARCHAR(255),
    tier VARCHAR(100),
    round VARCHAR(50),
    host_location VARCHAR(100),
    team1 VARCHAR(150),
    team2 VARCHAR(150),
    winner SMALLINT,
    score VARCHAR(100),
    team1_at_home BOOLEAN,
    team2_at_home BOOLEAN
);
