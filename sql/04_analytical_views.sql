-- BADMINTON ANALYTICS | 04 — Analytical views
-- SOURCE: All 12 CREATE VIEW statements recovered verbatim from the original SQL file.
-- Dependency order is preserved. Run ONLY on a clean DB after 03_warehouse_load.sql.
-- Do not rerun in the live existing database: the views already exist.
-- Score parsing uses numeric casts; it expects the curated scores accepted by the original project.

BEGIN;

-- v_player_matches
CREATE VIEW v_player_matches AS

SELECT
    match_id,
    date_id,
    tournament_id,
    player1_id AS player_id,
    player2_id AS opponent_id,
    1 AS player_side,
    CASE
        WHEN winner_player_id = player1_id THEN 'W'
        ELSE 'L'
    END AS result,
    team1_at_home AS at_home,
    round,
    score
FROM fact_matches

UNION ALL

SELECT
    match_id,
    date_id,
    tournament_id,
    player2_id AS player_id,
    player1_id AS opponent_id,
    2 AS player_side,
    CASE
        WHEN winner_player_id = player2_id THEN 'W'
        ELSE 'L'
    END AS result,
    team2_at_home AS at_home,
    round,
    score
FROM fact_matches;

-- v_player_yearly_performance
CREATE VIEW v_player_yearly_performance AS
SELECT
    p.player_id,
    p.player_name,
    d.year,
    COUNT(*) AS total_matches,
    COUNT(*) FILTER (WHERE v.result = 'W') AS wins,
    COUNT(*) FILTER (WHERE v.result = 'L') AS losses,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE v.result = 'W')
        / COUNT(*),
        2
    ) AS win_rate
FROM v_player_matches v
JOIN dim_player p
    ON v.player_id = p.player_id
JOIN dim_date d
    ON v.date_id = d.date_id
GROUP BY
    p.player_id,
    p.player_name,
    d.year;

-- v_player_head_to_head
CREATE VIEW v_player_head_to_head AS
SELECT
    p.player_id,
    p.player_name,
    o.player_id AS opponent_id,
    o.player_name AS opponent_name,

    COUNT(*) AS matches_played,

    COUNT(*) FILTER (
        WHERE v.result = 'W'
    ) AS wins,

    COUNT(*) FILTER (
        WHERE v.result = 'L'
    ) AS losses,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE v.result = 'W')
        / COUNT(*),
        2
    ) AS win_rate,

    MIN(v.date_id) AS first_meeting,
    MAX(v.date_id) AS last_meeting

FROM v_player_matches v

JOIN dim_player p
    ON v.player_id = p.player_id

JOIN dim_player o
    ON v.opponent_id = o.player_id

GROUP BY
    p.player_id,
    p.player_name,
    o.player_id,
    o.player_name;

-- v_player_tier_performance
CREATE VIEW v_player_tier_performance AS
SELECT
    p.player_id,
    p.player_name,
    t.tier,

    COUNT(*) AS total_matches,

    COUNT(*) FILTER (
        WHERE v.result = 'W'
    ) AS wins,

    COUNT(*) FILTER (
        WHERE v.result = 'L'
    ) AS losses,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE v.result = 'W')
        / COUNT(*),
        2
    ) AS win_rate

FROM v_player_matches v

JOIN dim_player p
    ON v.player_id = p.player_id

JOIN dim_tournament t
    ON v.tournament_id = t.tournament_id

GROUP BY
    p.player_id,
    p.player_name,
    t.tier;

-- v_player_round_performance
CREATE VIEW v_player_round_performance AS
SELECT
    p.player_id,
    p.player_name,
    v.round,

    COUNT(*) AS total_matches,

    COUNT(*) FILTER (
        WHERE v.result = 'W'
    ) AS wins,

    COUNT(*) FILTER (
        WHERE v.result = 'L'
    ) AS losses,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE v.result = 'W')
        / COUNT(*),
        2
    ) AS win_rate

FROM v_player_matches v

JOIN dim_player p
    ON v.player_id = p.player_id

GROUP BY
    p.player_id,
    p.player_name,
    v.round;

-- v_match_score_parsed
CREATE VIEW v_match_score_parsed AS
SELECT
    f.*,

    ARRAY_LENGTH(x.games, 1) AS game_parts,

    SPLIT_PART(x.games[1], '-', 1)::SMALLINT AS game1_team1,
    SPLIT_PART(x.games[1], '-', 2)::SMALLINT AS game1_team2,

    CASE
        WHEN ARRAY_LENGTH(x.games, 1) >= 2
        THEN SPLIT_PART(x.games[2], '-', 1)::SMALLINT
    END AS game2_team1,

    CASE
        WHEN ARRAY_LENGTH(x.games, 1) >= 2
        THEN SPLIT_PART(x.games[2], '-', 2)::SMALLINT
    END AS game2_team2,

    CASE
        WHEN ARRAY_LENGTH(x.games, 1) >= 3
        THEN SPLIT_PART(x.games[3], '-', 1)::SMALLINT
    END AS game3_team1,

    CASE
        WHEN ARRAY_LENGTH(x.games, 1) >= 3
        THEN SPLIT_PART(x.games[3], '-', 2)::SMALLINT
    END AS game3_team2

FROM fact_matches f

CROSS JOIN LATERAL (
    SELECT REGEXP_SPLIT_TO_ARRAY(TRIM(f.score), '\s+') AS games
) x;

-- v_match_quality
CREATE VIEW v_match_quality AS
WITH score_checks AS (
    SELECT
        *,

        (
            (GREATEST(game1_team1, game1_team2) = 21
                AND LEAST(game1_team1, game1_team2) <= 19)
            OR
            (GREATEST(game1_team1, game1_team2) BETWEEN 22 AND 29
                AND ABS(game1_team1 - game1_team2) = 2)
            OR
            (GREATEST(game1_team1, game1_team2) = 30
                AND LEAST(game1_team1, game1_team2) BETWEEN 28 AND 29)
        ) AS game1_complete,

        (
            (GREATEST(game2_team1, game2_team2) = 21
                AND LEAST(game2_team1, game2_team2) <= 19)
            OR
            (GREATEST(game2_team1, game2_team2) BETWEEN 22 AND 29
                AND ABS(game2_team1 - game2_team2) = 2)
            OR
            (GREATEST(game2_team1, game2_team2) = 30
                AND LEAST(game2_team1, game2_team2) BETWEEN 28 AND 29)
        ) AS game2_complete,

        CASE
            WHEN game_parts = 3 THEN
                (
                    (GREATEST(game3_team1, game3_team2) = 21
                        AND LEAST(game3_team1, game3_team2) <= 19)
                    OR
                    (GREATEST(game3_team1, game3_team2) BETWEEN 22 AND 29
                        AND ABS(game3_team1 - game3_team2) = 2)
                    OR
                    (GREATEST(game3_team1, game3_team2) = 30
                        AND LEAST(game3_team1, game3_team2) BETWEEN 28 AND 29)
                )
            ELSE NULL
        END AS game3_complete

    FROM v_match_score_parsed
),

game_counts AS (
    SELECT
        *,

        (game1_team1 > game1_team2)::INT
        + (game2_team1 > game2_team2)::INT
        + CASE
            WHEN game_parts = 3
            THEN (game3_team1 > game3_team2)::INT
            ELSE 0
          END AS team1_game_wins,

        (game1_team2 > game1_team1)::INT
        + (game2_team2 > game2_team1)::INT
        + CASE
            WHEN game_parts = 3
            THEN (game3_team2 > game3_team1)::INT
            ELSE 0
          END AS team2_game_wins

    FROM score_checks
)

SELECT
    *,
    CASE
        WHEN game_parts NOT IN (2,3)
            THEN 'Incomplete'

        WHEN game1_complete IS NOT TRUE
            OR game2_complete IS NOT TRUE
            THEN 'Incomplete'

        WHEN game_parts = 3
            AND game3_complete IS NOT TRUE
            THEN 'Incomplete'

        WHEN GREATEST(team1_game_wins, team2_game_wins) <> 2
            THEN 'Incomplete'

        ELSE 'Complete'
    END AS score_status

FROM game_counts;

-- v_player_match_features
CREATE VIEW v_player_match_features AS
SELECT
    v.match_id,
    v.date_id,
    v.tournament_id,
    v.player_id,
    v.opponent_id,
    v.result,
    v.round,
    v.score,
    v.at_home,

    q.score_status,
    q.game_parts,

    CASE
        WHEN v.player_side = 1 THEN q.team1_game_wins
        ELSE q.team2_game_wins
    END AS player_game_wins,

    CASE
        WHEN v.player_side = 1 THEN q.team2_game_wins
        ELSE q.team1_game_wins
    END AS opponent_game_wins,

    CASE
        WHEN q.score_status = 'Complete'
        THEN
            CASE
                WHEN v.player_side = 1
                    THEN q.game1_team1 > q.game1_team2
                ELSE q.game1_team2 > q.game1_team1
            END
    END AS won_game1,

    CASE
        WHEN q.score_status = 'Complete'
             AND q.game_parts = 2
        THEN TRUE
        ELSE FALSE
    END AS straight_game_match,

    CASE
        WHEN q.score_status = 'Complete'
             AND q.game_parts = 2
             AND v.result = 'W'
        THEN TRUE
        ELSE FALSE
    END AS straight_game_win,

    CASE
        WHEN q.score_status = 'Complete'
             AND q.game_parts = 3
        THEN TRUE
        ELSE FALSE
    END AS three_game_match,

    CASE
        WHEN q.score_status = 'Complete'
             AND q.game_parts = 3
             AND v.result = 'W'
        THEN TRUE
        ELSE FALSE
    END AS deciding_game_win,

    CASE
        WHEN q.score_status = 'Complete'
             AND q.game_parts = 3
             AND v.result = 'W'
             AND (
                CASE
                    WHEN v.player_side = 1
                        THEN q.game1_team1 < q.game1_team2
                    ELSE q.game1_team2 < q.game1_team1
                END
             )
        THEN TRUE
        ELSE FALSE
    END AS comeback_win

FROM v_player_matches v
JOIN v_match_quality q
    ON v.match_id = q.match_id;

-- v_player_advanced_kpis
CREATE VIEW v_player_advanced_kpis AS
SELECT
    p.player_id,
    p.player_name,

    COUNT(*) FILTER (
        WHERE f.score_status = 'Complete'
    ) AS complete_matches,

    COUNT(*) FILTER (
        WHERE f.straight_game_win
    ) AS straight_game_wins,

    COUNT(*) FILTER (
        WHERE f.three_game_match
    ) AS three_game_matches,

    COUNT(*) FILTER (
        WHERE f.deciding_game_win
    ) AS deciding_game_wins,

    COUNT(*) FILTER (
        WHERE f.comeback_win
    ) AS comeback_wins,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE f.straight_game_win
        )
        /
        NULLIF(
            COUNT(*) FILTER (
                WHERE f.score_status = 'Complete'
            ),
            0
        ),
        2
    ) AS straight_game_win_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE f.deciding_game_win
        )
        /
        NULLIF(
            COUNT(*) FILTER (
                WHERE f.three_game_match
            ),
            0
        ),
        2
    ) AS deciding_game_win_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE f.comeback_win
        )
        /
        NULLIF(
            COUNT(*) FILTER (
                WHERE f.score_status = 'Complete'
                  AND f.won_game1 = FALSE
            ),
            0
        ),
        2
    ) AS comeback_win_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE f.score_status = 'Complete'
              AND f.won_game1 = TRUE
              AND f.result = 'W'
        )
        /
        NULLIF(
            COUNT(*) FILTER (
                WHERE f.score_status = 'Complete'
                  AND f.won_game1 = TRUE
            ),
            0
        ),
        2
    ) AS first_game_conversion_pct

FROM v_player_match_features f

JOIN dim_player p
    ON f.player_id = p.player_id

GROUP BY
    p.player_id,
    p.player_name;

-- v_player_recent_form
CREATE VIEW v_player_recent_form AS
WITH ranked_matches AS (
    SELECT
        v.player_id,
        p.player_name,
        v.opponent_id,
        o.player_name AS opponent_name,
        v.date_id,
        v.match_id,
        v.result,
        v.round,
        v.score,

        ROW_NUMBER() OVER (
            PARTITION BY v.player_id
            ORDER BY v.date_id DESC, v.match_id DESC
        ) AS match_rank

    FROM v_player_matches v

    JOIN dim_player p
        ON v.player_id = p.player_id

    JOIN dim_player o
        ON v.opponent_id = o.player_id
)

SELECT
    player_id,
    player_name,

    COUNT(*) AS recent_matches,

    COUNT(*) FILTER (
        WHERE result = 'W'
    ) AS recent_wins,

    COUNT(*) FILTER (
        WHERE result = 'L'
    ) AS recent_losses,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE result = 'W'
        )
        / COUNT(*),
        2
    ) AS recent_win_rate

FROM ranked_matches

WHERE match_rank <= 10

GROUP BY
    player_id,
    player_name;

-- v_player_last10_matches
CREATE VIEW v_player_last10_matches AS
WITH ranked_matches AS (
    SELECT
        v.player_id,
        p.player_name,
        v.opponent_id,
        o.player_name AS opponent_name,
        v.date_id,
        t.tournament_name,
        t.tier,
        v.round,
        v.result,
        v.score,
        ROW_NUMBER() OVER (
            PARTITION BY v.player_id
            ORDER BY v.date_id DESC, v.match_id DESC
        ) AS match_rank
    FROM v_player_matches v
    JOIN dim_player p
        ON v.player_id = p.player_id
    JOIN dim_player o
        ON v.opponent_id = o.player_id
    JOIN dim_tournament t
        ON v.tournament_id = t.tournament_id
)

SELECT
    player_id,
    player_name,
    match_rank,
    date_id,
    tournament_name,
    tier,
    round,
    opponent_name,
    result,
    score
FROM ranked_matches
WHERE match_rank <= 10;

-- v_player_home_performance
CREATE VIEW v_player_home_performance AS
SELECT
    p.player_id,
    p.player_name,

    CASE
        WHEN v.at_home = TRUE THEN 'Home'
        ELSE 'Away/Neutral'
    END AS location_status,

    COUNT(*) AS total_matches,

    COUNT(*) FILTER (
        WHERE v.result = 'W'
    ) AS wins,

    COUNT(*) FILTER (
        WHERE v.result = 'L'
    ) AS losses,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE v.result = 'W'
        )
        / COUNT(*),
        2
    ) AS win_rate

FROM v_player_matches v

JOIN dim_player p
    ON v.player_id = p.player_id

GROUP BY
    p.player_id,
    p.player_name,
    location_status;

COMMIT;
