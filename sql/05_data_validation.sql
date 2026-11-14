-- BADMINTON ANALYTICS | 05 — Read-only warehouse validation
-- SOURCE: validation queries from the saved workflow, plus labeled reconciliation checks.
-- This file contains only SELECT statements. Safe for a read-only database account.
-- Expected counts are reference observations from the validated 2018–2025 project.

-- A. Core warehouse and analytics-view counts.
SELECT 'stg_matches' AS object_name, COUNT(*) AS row_count
FROM stg_matches

UNION ALL

SELECT 'dim_player', COUNT(*)
FROM dim_player

UNION ALL

SELECT 'dim_tournament', COUNT(*)
FROM dim_tournament

UNION ALL

SELECT 'dim_date', COUNT(*)
FROM dim_date

UNION ALL

SELECT 'fact_matches', COUNT(*)
FROM fact_matches

UNION ALL

SELECT 'v_player_matches', COUNT(*)
FROM v_player_matches

UNION ALL

SELECT 'v_match_score_parsed', COUNT(*)
FROM v_match_score_parsed

UNION ALL

SELECT 'v_match_quality', COUNT(*)
FROM v_match_quality

UNION ALL

SELECT 'v_player_match_features', COUNT(*)
FROM v_player_match_features;

-- B. Verify match identity, winner integrity and player distinctness.
SELECT
    COUNT(*) AS total_matches,

    COUNT(*) FILTER (
        WHERE player1_id = player2_id
    ) AS same_player_matches,

    COUNT(*) FILTER (
        WHERE winner_player_id <> player1_id
          AND winner_player_id <> player2_id
    ) AS invalid_winner_player,

    COUNT(*) FILTER (
        WHERE winner_side = 1
          AND winner_player_id <> player1_id
    ) AS wrong_team1_winner,

    COUNT(*) FILTER (
        WHERE winner_side = 2
          AND winner_player_id <> player2_id
    ) AS wrong_team2_winner
FROM fact_matches;

-- C. Yearly fact-match counts (sum should be 10,444).
SELECT
    EXTRACT(YEAR FROM date_id) AS year,
    COUNT(*) AS matches
FROM fact_matches
GROUP BY EXTRACT(YEAR FROM date_id)
ORDER BY year;

-- D. Score-completeness categories; expected Complete 10,245, Incomplete 199.
SELECT
    score_status,
    COUNT(*) AS matches
FROM v_match_quality
GROUP BY score_status
ORDER BY score_status;

-- E. Reconcile unique matches, player perspectives and score quality.
SELECT
    (SELECT COUNT(*)
     FROM fact_matches) AS unique_matches,

    (SELECT COUNT(*)
     FROM v_player_matches) AS player_match_rows,

    (SELECT COUNT(DISTINCT match_id)
     FROM v_player_matches) AS distinct_match_ids,

    (SELECT COUNT(*)
     FROM v_match_quality
     WHERE score_status = 'Complete') AS complete_scores,

    (SELECT COUNT(*)
     FROM v_match_quality
     WHERE score_status = 'Incomplete') AS incomplete_scores;

-- F. Reconcile match totals by tournament tier (including any NULL tier).
SELECT
    COALESCE(t.tier, '(Blank)') AS tournament_tier,
    COUNT(*) AS unique_matches
FROM fact_matches AS f
LEFT JOIN dim_tournament AS t
  ON f.tournament_id = t.tournament_id
GROUP BY COALESCE(t.tier, '(Blank)')
ORDER BY unique_matches DESC;

-- G. Check for orphaned dimension links (foreign keys should prevent these).
SELECT
    COUNT(*) FILTER (WHERE p1.player_id IS NULL) AS missing_player1,
    COUNT(*) FILTER (WHERE p2.player_id IS NULL) AS missing_player2,
    COUNT(*) FILTER (WHERE t.tournament_id IS NULL) AS missing_tournament,
    COUNT(*) FILTER (WHERE d.date_id IS NULL) AS missing_date
FROM fact_matches AS f
LEFT JOIN dim_player AS p1 ON p1.player_id = f.player1_id
LEFT JOIN dim_player AS p2 ON p2.player_id = f.player2_id
LEFT JOIN dim_tournament AS t ON t.tournament_id = f.tournament_id
LEFT JOIN dim_date AS d ON d.date_id = f.date_id;

-- H. Anthony Ginting reconciliation; SQL observation: 250 unique matches, 157 wins, 93 losses.
p.player_name,
    COUNT(*) AS total_match_rows,
    COUNT(DISTINCT v.match_id) AS unique_matches,
    COUNT(*) FILTER (
        WHERE v.result = 'W'
    ) AS wins,
    COUNT(*) FILTER (
        WHERE v.result = 'L'
    ) AS losses
FROM v_player_matches v
JOIN dim_player p
    ON v.player_id = p.player_id
WHERE p.player_name ILIKE '%GINTING%'
GROUP BY
    p.player_id,
    p.player_name;

-- I. List the PostgreSQL public tables and views.
SELECT
    table_name AS object_name,
    CASE
        WHEN table_type = 'BASE TABLE' THEN 'Table'
        WHEN table_type = 'VIEW' THEN 'View'
        ELSE table_type
    END AS object_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type IN ('BASE TABLE', 'VIEW')
ORDER BY
    object_type,
    object_name;
