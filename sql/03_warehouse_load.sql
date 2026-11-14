-- BADMINTON ANALYTICS | 03 — Warehouse tables & initial load
-- SOURCE: 02_original_sql_workflow.sql (deduplicated, successful DDL/DML only).
-- PREREQUISITE: 02a + source data import + 02b date conversion.
-- Run ONLY in a clean database without the target dimension/fact tables.
-- Never run this on the existing populated warehouse: INSERT statements are not rerunnable.
-- The original script included duplicate INSERT attempts for dim_player/dim_tournament;
-- each population query appears only ONCE here.

BEGIN;

-- Dimension: players
CREATE TABLE dim_player (
    player_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    player_name VARCHAR(150) NOT NULL UNIQUE
);

INSERT INTO dim_player (player_name)
SELECT player_name
FROM (
    SELECT TRIM(team1) AS player_name
    FROM stg_matches

    UNION

    SELECT TRIM(team2) AS player_name
    FROM stg_matches
) players
WHERE player_name IS NOT NULL
  AND player_name <> ''
ORDER BY player_name;

-- Dimension: tournaments
CREATE TABLE dim_tournament (
    tournament_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tournament_name VARCHAR(255) NOT NULL,
    tier VARCHAR(100),
    host_location VARCHAR(100),
    UNIQUE (tournament_name, tier, host_location)
);

INSERT INTO dim_tournament (
    tournament_name,
    tier,
    host_location
)
SELECT DISTINCT
    TRIM(tournament),
    TRIM(tier),
    TRIM(host_location)
FROM stg_matches
WHERE tournament IS NOT NULL;

-- Dimension: dates (full 2018–2025 calendar)
CREATE TABLE dim_date (
    date_id DATE PRIMARY KEY,
    year SMALLINT NOT NULL,
    quarter SMALLINT NOT NULL,
    month SMALLINT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    day SMALLINT NOT NULL,
    day_of_week SMALLINT NOT NULL,
    day_name VARCHAR(20) NOT NULL
);

INSERT INTO dim_date (
    date_id,
    year,
    quarter,
    month,
    month_name,
    day,
    day_of_week,
    day_name
)
SELECT
    d::DATE,
    EXTRACT(YEAR FROM d)::SMALLINT,
    EXTRACT(QUARTER FROM d)::SMALLINT,
    EXTRACT(MONTH FROM d)::SMALLINT,
    TO_CHAR(d, 'Month'),
    EXTRACT(DAY FROM d)::SMALLINT,
    EXTRACT(ISODOW FROM d)::SMALLINT,
    TO_CHAR(d, 'Day')
FROM GENERATE_SERIES(
    DATE '2018-01-01',
    DATE '2025-12-31',
    INTERVAL '1 day'
) AS d;

-- Fact: one row per match (references all dimensions)
CREATE TABLE fact_matches (
    match_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    date_id DATE NOT NULL,
    tournament_id BIGINT NOT NULL,

    player1_id BIGINT NOT NULL,
    player2_id BIGINT NOT NULL,
    winner_player_id BIGINT NOT NULL,

    round VARCHAR(50) NOT NULL,
    winner_side SMALLINT NOT NULL,
    score VARCHAR(100) NOT NULL,

    team1_at_home BOOLEAN NOT NULL,
    team2_at_home BOOLEAN NOT NULL,

    CONSTRAINT fk_match_date
        FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_match_tournament
        FOREIGN KEY (tournament_id)
        REFERENCES dim_tournament(tournament_id),

    CONSTRAINT fk_player1
        FOREIGN KEY (player1_id)
        REFERENCES dim_player(player_id),

    CONSTRAINT fk_player2
        FOREIGN KEY (player2_id)
        REFERENCES dim_player(player_id),

    CONSTRAINT fk_winner_player
        FOREIGN KEY (winner_player_id)
        REFERENCES dim_player(player_id),

    CONSTRAINT chk_winner_side
        CHECK (winner_side IN (1,2)),

    CONSTRAINT chk_different_players
        CHECK (player1_id <> player2_id)
);

INSERT INTO fact_matches (
    date_id,
    tournament_id,
    player1_id,
    player2_id,
    winner_player_id,
    round,
    winner_side,
    score,
    team1_at_home,
    team2_at_home
)
SELECT
    s.match_date,
    t.tournament_id,
    p1.player_id,
    p2.player_id,

    CASE
        WHEN s.winner = 1 THEN p1.player_id
        WHEN s.winner = 2 THEN p2.player_id
    END AS winner_player_id,

    TRIM(s.round),
    s.winner,
    s.score,
    s.team1_at_home,
    s.team2_at_home

FROM stg_matches s

JOIN dim_player p1
    ON TRIM(s.team1) = p1.player_name

JOIN dim_player p2
    ON TRIM(s.team2) = p2.player_name

JOIN dim_tournament t
    ON TRIM(s.tournament) = t.tournament_name
    AND TRIM(s.tier) IS NOT DISTINCT FROM t.tier
    AND TRIM(s.host_location) IS NOT DISTINCT FROM t.host_location;

COMMIT;

-- Expected after successful load:
-- dim_player: 1,047 rows; dim_tournament: 246 rows;
-- dim_date: 2,922 rows; fact_matches: 10,444 rows.
-- Run 05_data_validation.sql to compare observed values and investigate exceptions.
