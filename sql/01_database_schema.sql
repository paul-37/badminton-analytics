--
-- PostgreSQL database dump
--

\restrict MMjYd2oqhhDEZ5EjdbWg06g8mE8LCWleMfNWgvNwntgEMVAjC3WEkajXnCbhMMU

-- Dumped from database version 18.2
-- Dumped by pg_dump version 18.2

-- Started on 2026-11-11 15:09:14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 224 (class 1259 OID 24642)
-- Name: dim_date; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dim_date (
    date_id date NOT NULL,
    year smallint NOT NULL,
    quarter smallint NOT NULL,
    month smallint NOT NULL,
    month_name character varying(20) NOT NULL,
    day smallint NOT NULL,
    day_of_week smallint NOT NULL,
    day_name character varying(20) NOT NULL
);


ALTER TABLE public.dim_date OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 24621)
-- Name: dim_player; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dim_player (
    player_id bigint NOT NULL,
    player_name character varying(150) NOT NULL
);


ALTER TABLE public.dim_player OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 24620)
-- Name: dim_player_player_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.dim_player ALTER COLUMN player_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.dim_player_player_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 223 (class 1259 OID 24632)
-- Name: dim_tournament; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dim_tournament (
    tournament_id bigint NOT NULL,
    tournament_name character varying(255) NOT NULL,
    tier character varying(100),
    host_location character varying(100)
);


ALTER TABLE public.dim_tournament OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 24631)
-- Name: dim_tournament_tournament_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.dim_tournament ALTER COLUMN tournament_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.dim_tournament_tournament_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 226 (class 1259 OID 24656)
-- Name: fact_matches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fact_matches (
    match_id bigint NOT NULL,
    date_id date NOT NULL,
    tournament_id bigint NOT NULL,
    player1_id bigint NOT NULL,
    player2_id bigint NOT NULL,
    winner_player_id bigint NOT NULL,
    round character varying(50) NOT NULL,
    winner_side smallint NOT NULL,
    score character varying(100) NOT NULL,
    team1_at_home boolean NOT NULL,
    team2_at_home boolean NOT NULL,
    CONSTRAINT chk_different_players CHECK ((player1_id <> player2_id)),
    CONSTRAINT chk_winner_side CHECK ((winner_side = ANY (ARRAY[1, 2])))
);


ALTER TABLE public.fact_matches OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 24655)
-- Name: fact_matches_match_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.fact_matches ALTER COLUMN match_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.fact_matches_match_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 219 (class 1259 OID 24605)
-- Name: stg_matches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stg_matches (
    date character varying(20),
    discipline character varying(10),
    tournament character varying(255),
    tier character varying(100),
    round character varying(50),
    host_location character varying(100),
    team1 character varying(150),
    team2 character varying(150),
    winner smallint,
    score character varying(100),
    team1_at_home boolean,
    team2_at_home boolean,
    match_date date
);


ALTER TABLE public.stg_matches OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 24724)
-- Name: v_match_score_parsed; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_match_score_parsed AS
 SELECT f.match_id,
    f.date_id,
    f.tournament_id,
    f.player1_id,
    f.player2_id,
    f.winner_player_id,
    f.round,
    f.winner_side,
    f.score,
    f.team1_at_home,
    f.team2_at_home,
    array_length(x.games, 1) AS game_parts,
    (split_part(x.games[1], '-'::text, 1))::smallint AS game1_team1,
    (split_part(x.games[1], '-'::text, 2))::smallint AS game1_team2,
        CASE
            WHEN (array_length(x.games, 1) >= 2) THEN (split_part(x.games[2], '-'::text, 1))::smallint
            ELSE NULL::smallint
        END AS game2_team1,
        CASE
            WHEN (array_length(x.games, 1) >= 2) THEN (split_part(x.games[2], '-'::text, 2))::smallint
            ELSE NULL::smallint
        END AS game2_team2,
        CASE
            WHEN (array_length(x.games, 1) >= 3) THEN (split_part(x.games[3], '-'::text, 1))::smallint
            ELSE NULL::smallint
        END AS game3_team1,
        CASE
            WHEN (array_length(x.games, 1) >= 3) THEN (split_part(x.games[3], '-'::text, 2))::smallint
            ELSE NULL::smallint
        END AS game3_team2
   FROM (public.fact_matches f
     CROSS JOIN LATERAL ( SELECT regexp_split_to_array(TRIM(BOTH FROM f.score), '\s+'::text) AS games) x);


ALTER VIEW public.v_match_score_parsed OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 24729)
-- Name: v_match_quality; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_match_quality AS
 WITH score_checks AS (
         SELECT v_match_score_parsed.match_id,
            v_match_score_parsed.date_id,
            v_match_score_parsed.tournament_id,
            v_match_score_parsed.player1_id,
            v_match_score_parsed.player2_id,
            v_match_score_parsed.winner_player_id,
            v_match_score_parsed.round,
            v_match_score_parsed.winner_side,
            v_match_score_parsed.score,
            v_match_score_parsed.team1_at_home,
            v_match_score_parsed.team2_at_home,
            v_match_score_parsed.game_parts,
            v_match_score_parsed.game1_team1,
            v_match_score_parsed.game1_team2,
            v_match_score_parsed.game2_team1,
            v_match_score_parsed.game2_team2,
            v_match_score_parsed.game3_team1,
            v_match_score_parsed.game3_team2,
            (((GREATEST(v_match_score_parsed.game1_team1, v_match_score_parsed.game1_team2) = 21) AND (LEAST(v_match_score_parsed.game1_team1, v_match_score_parsed.game1_team2) <= 19)) OR (((GREATEST(v_match_score_parsed.game1_team1, v_match_score_parsed.game1_team2) >= 22) AND (GREATEST(v_match_score_parsed.game1_team1, v_match_score_parsed.game1_team2) <= 29)) AND (abs((v_match_score_parsed.game1_team1 - v_match_score_parsed.game1_team2)) = 2)) OR ((GREATEST(v_match_score_parsed.game1_team1, v_match_score_parsed.game1_team2) = 30) AND ((LEAST(v_match_score_parsed.game1_team1, v_match_score_parsed.game1_team2) >= 28) AND (LEAST(v_match_score_parsed.game1_team1, v_match_score_parsed.game1_team2) <= 29)))) AS game1_complete,
            (((GREATEST(v_match_score_parsed.game2_team1, v_match_score_parsed.game2_team2) = 21) AND (LEAST(v_match_score_parsed.game2_team1, v_match_score_parsed.game2_team2) <= 19)) OR (((GREATEST(v_match_score_parsed.game2_team1, v_match_score_parsed.game2_team2) >= 22) AND (GREATEST(v_match_score_parsed.game2_team1, v_match_score_parsed.game2_team2) <= 29)) AND (abs((v_match_score_parsed.game2_team1 - v_match_score_parsed.game2_team2)) = 2)) OR ((GREATEST(v_match_score_parsed.game2_team1, v_match_score_parsed.game2_team2) = 30) AND ((LEAST(v_match_score_parsed.game2_team1, v_match_score_parsed.game2_team2) >= 28) AND (LEAST(v_match_score_parsed.game2_team1, v_match_score_parsed.game2_team2) <= 29)))) AS game2_complete,
                CASE
                    WHEN (v_match_score_parsed.game_parts = 3) THEN (((GREATEST(v_match_score_parsed.game3_team1, v_match_score_parsed.game3_team2) = 21) AND (LEAST(v_match_score_parsed.game3_team1, v_match_score_parsed.game3_team2) <= 19)) OR (((GREATEST(v_match_score_parsed.game3_team1, v_match_score_parsed.game3_team2) >= 22) AND (GREATEST(v_match_score_parsed.game3_team1, v_match_score_parsed.game3_team2) <= 29)) AND (abs((v_match_score_parsed.game3_team1 - v_match_score_parsed.game3_team2)) = 2)) OR ((GREATEST(v_match_score_parsed.game3_team1, v_match_score_parsed.game3_team2) = 30) AND ((LEAST(v_match_score_parsed.game3_team1, v_match_score_parsed.game3_team2) >= 28) AND (LEAST(v_match_score_parsed.game3_team1, v_match_score_parsed.game3_team2) <= 29))))
                    ELSE NULL::boolean
                END AS game3_complete
           FROM public.v_match_score_parsed
        ), game_counts AS (
         SELECT score_checks.match_id,
            score_checks.date_id,
            score_checks.tournament_id,
            score_checks.player1_id,
            score_checks.player2_id,
            score_checks.winner_player_id,
            score_checks.round,
            score_checks.winner_side,
            score_checks.score,
            score_checks.team1_at_home,
            score_checks.team2_at_home,
            score_checks.game_parts,
            score_checks.game1_team1,
            score_checks.game1_team2,
            score_checks.game2_team1,
            score_checks.game2_team2,
            score_checks.game3_team1,
            score_checks.game3_team2,
            score_checks.game1_complete,
            score_checks.game2_complete,
            score_checks.game3_complete,
            ((((score_checks.game1_team1 > score_checks.game1_team2))::integer + ((score_checks.game2_team1 > score_checks.game2_team2))::integer) +
                CASE
                    WHEN (score_checks.game_parts = 3) THEN ((score_checks.game3_team1 > score_checks.game3_team2))::integer
                    ELSE 0
                END) AS team1_game_wins,
            ((((score_checks.game1_team2 > score_checks.game1_team1))::integer + ((score_checks.game2_team2 > score_checks.game2_team1))::integer) +
                CASE
                    WHEN (score_checks.game_parts = 3) THEN ((score_checks.game3_team2 > score_checks.game3_team1))::integer
                    ELSE 0
                END) AS team2_game_wins
           FROM score_checks
        )
 SELECT match_id,
    date_id,
    tournament_id,
    player1_id,
    player2_id,
    winner_player_id,
    round,
    winner_side,
    score,
    team1_at_home,
    team2_at_home,
    game_parts,
    game1_team1,
    game1_team2,
    game2_team1,
    game2_team2,
    game3_team1,
    game3_team2,
    game1_complete,
    game2_complete,
    game3_complete,
    team1_game_wins,
    team2_game_wins,
        CASE
            WHEN (game_parts <> ALL (ARRAY[2, 3])) THEN 'Incomplete'::text
            WHEN ((game1_complete IS NOT TRUE) OR (game2_complete IS NOT TRUE)) THEN 'Incomplete'::text
            WHEN ((game_parts = 3) AND (game3_complete IS NOT TRUE)) THEN 'Incomplete'::text
            WHEN (GREATEST(team1_game_wins, team2_game_wins) <> 2) THEN 'Incomplete'::text
            ELSE 'Complete'::text
        END AS score_status
   FROM game_counts;


ALTER VIEW public.v_match_quality OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 24699)
-- Name: v_player_matches; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_player_matches AS
 SELECT fact_matches.match_id,
    fact_matches.date_id,
    fact_matches.tournament_id,
    fact_matches.player1_id AS player_id,
    fact_matches.player2_id AS opponent_id,
    1 AS player_side,
        CASE
            WHEN (fact_matches.winner_player_id = fact_matches.player1_id) THEN 'W'::text
            ELSE 'L'::text
        END AS result,
    fact_matches.team1_at_home AS at_home,
    fact_matches.round,
    fact_matches.score
   FROM public.fact_matches
UNION ALL
 SELECT fact_matches.match_id,
    fact_matches.date_id,
    fact_matches.tournament_id,
    fact_matches.player2_id AS player_id,
    fact_matches.player1_id AS opponent_id,
    2 AS player_side,
        CASE
            WHEN (fact_matches.winner_player_id = fact_matches.player2_id) THEN 'W'::text
            ELSE 'L'::text
        END AS result,
    fact_matches.team2_at_home AS at_home,
    fact_matches.round,
    fact_matches.score
   FROM public.fact_matches;


ALTER VIEW public.v_player_matches OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 24735)
-- Name: v_player_match_features; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_player_match_features AS
 SELECT v.match_id,
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
            WHEN (v.player_side = 1) THEN q.team1_game_wins
            ELSE q.team2_game_wins
        END AS player_game_wins,
        CASE
            WHEN (v.player_side = 1) THEN q.team2_game_wins
            ELSE q.team1_game_wins
        END AS opponent_game_wins,
        CASE
            WHEN (q.score_status = 'Complete'::text) THEN
            CASE
                WHEN (v.player_side = 1) THEN (q.game1_team1 > q.game1_team2)
                ELSE (q.game1_team2 > q.game1_team1)
            END
            ELSE NULL::boolean
        END AS won_game1,
        CASE
            WHEN ((q.score_status = 'Complete'::text) AND (q.game_parts = 2)) THEN true
            ELSE false
        END AS straight_game_match,
        CASE
            WHEN ((q.score_status = 'Complete'::text) AND (q.game_parts = 2) AND (v.result = 'W'::text)) THEN true
            ELSE false
        END AS straight_game_win,
        CASE
            WHEN ((q.score_status = 'Complete'::text) AND (q.game_parts = 3)) THEN true
            ELSE false
        END AS three_game_match,
        CASE
            WHEN ((q.score_status = 'Complete'::text) AND (q.game_parts = 3) AND (v.result = 'W'::text)) THEN true
            ELSE false
        END AS deciding_game_win,
        CASE
            WHEN ((q.score_status = 'Complete'::text) AND (q.game_parts = 3) AND (v.result = 'W'::text) AND
            CASE
                WHEN (v.player_side = 1) THEN (q.game1_team1 < q.game1_team2)
                ELSE (q.game1_team2 < q.game1_team1)
            END) THEN true
            ELSE false
        END AS comeback_win
   FROM (public.v_player_matches v
     JOIN public.v_match_quality q ON ((v.match_id = q.match_id)));


ALTER VIEW public.v_player_match_features OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 24740)
-- Name: v_player_advanced_kpis; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_player_advanced_kpis AS
 SELECT p.player_id,
    p.player_name,
    count(*) FILTER (WHERE (f.score_status = 'Complete'::text)) AS complete_matches,
    count(*) FILTER (WHERE f.straight_game_win) AS straight_game_wins,
    count(*) FILTER (WHERE f.three_game_match) AS three_game_matches,
    count(*) FILTER (WHERE f.deciding_game_win) AS deciding_game_wins,
    count(*) FILTER (WHERE f.comeback_win) AS comeback_wins,
    round(((100.0 * (count(*) FILTER (WHERE f.straight_game_win))::numeric) / (NULLIF(count(*) FILTER (WHERE (f.score_status = 'Complete'::text)), 0))::numeric), 2) AS straight_game_win_pct,
    round(((100.0 * (count(*) FILTER (WHERE f.deciding_game_win))::numeric) / (NULLIF(count(*) FILTER (WHERE f.three_game_match), 0))::numeric), 2) AS deciding_game_win_pct,
    round(((100.0 * (count(*) FILTER (WHERE f.comeback_win))::numeric) / (NULLIF(count(*) FILTER (WHERE ((f.score_status = 'Complete'::text) AND (f.won_game1 = false))), 0))::numeric), 2) AS comeback_win_pct,
    round(((100.0 * (count(*) FILTER (WHERE ((f.score_status = 'Complete'::text) AND (f.won_game1 = true) AND (f.result = 'W'::text))))::numeric) / (NULLIF(count(*) FILTER (WHERE ((f.score_status = 'Complete'::text) AND (f.won_game1 = true))), 0))::numeric), 2) AS first_game_conversion_pct
   FROM (public.v_player_match_features f
     JOIN public.dim_player p ON ((f.player_id = p.player_id)))
  GROUP BY p.player_id, p.player_name;


ALTER VIEW public.v_player_advanced_kpis OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 24709)
-- Name: v_player_head_to_head; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_player_head_to_head AS
 SELECT p.player_id,
    p.player_name,
    o.player_id AS opponent_id,
    o.player_name AS opponent_name,
    count(*) AS matches_played,
    count(*) FILTER (WHERE (v.result = 'W'::text)) AS wins,
    count(*) FILTER (WHERE (v.result = 'L'::text)) AS losses,
    round(((100.0 * (count(*) FILTER (WHERE (v.result = 'W'::text)))::numeric) / (count(*))::numeric), 2) AS win_rate,
    min(v.date_id) AS first_meeting,
    max(v.date_id) AS last_meeting
   FROM ((public.v_player_matches v
     JOIN public.dim_player p ON ((v.player_id = p.player_id)))
     JOIN public.dim_player o ON ((v.opponent_id = o.player_id)))
  GROUP BY p.player_id, p.player_name, o.player_id, o.player_name;


ALTER VIEW public.v_player_head_to_head OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 24755)
-- Name: v_player_home_performance; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_player_home_performance AS
 SELECT p.player_id,
    p.player_name,
        CASE
            WHEN (v.at_home = true) THEN 'Home'::text
            ELSE 'Away/Neutral'::text
        END AS location_status,
    count(*) AS total_matches,
    count(*) FILTER (WHERE (v.result = 'W'::text)) AS wins,
    count(*) FILTER (WHERE (v.result = 'L'::text)) AS losses,
    round(((100.0 * (count(*) FILTER (WHERE (v.result = 'W'::text)))::numeric) / (count(*))::numeric), 2) AS win_rate
   FROM (public.v_player_matches v
     JOIN public.dim_player p ON ((v.player_id = p.player_id)))
  GROUP BY p.player_id, p.player_name,
        CASE
            WHEN (v.at_home = true) THEN 'Home'::text
            ELSE 'Away/Neutral'::text
        END;


ALTER VIEW public.v_player_home_performance OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 24750)
-- Name: v_player_last10_matches; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_player_last10_matches AS
 WITH ranked_matches AS (
         SELECT v.player_id,
            p.player_name,
            v.opponent_id,
            o.player_name AS opponent_name,
            v.date_id,
            t.tournament_name,
            t.tier,
            v.round,
            v.result,
            v.score,
            row_number() OVER (PARTITION BY v.player_id ORDER BY v.date_id DESC, v.match_id DESC) AS match_rank
           FROM (((public.v_player_matches v
             JOIN public.dim_player p ON ((v.player_id = p.player_id)))
             JOIN public.dim_player o ON ((v.opponent_id = o.player_id)))
             JOIN public.dim_tournament t ON ((v.tournament_id = t.tournament_id)))
        )
 SELECT player_id,
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
  WHERE (match_rank <= 10);


ALTER VIEW public.v_player_last10_matches OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 24745)
-- Name: v_player_recent_form; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_player_recent_form AS
 WITH ranked_matches AS (
         SELECT v.player_id,
            p.player_name,
            v.opponent_id,
            o.player_name AS opponent_name,
            v.date_id,
            v.match_id,
            v.result,
            v.round,
            v.score,
            row_number() OVER (PARTITION BY v.player_id ORDER BY v.date_id DESC, v.match_id DESC) AS match_rank
           FROM ((public.v_player_matches v
             JOIN public.dim_player p ON ((v.player_id = p.player_id)))
             JOIN public.dim_player o ON ((v.opponent_id = o.player_id)))
        )
 SELECT player_id,
    player_name,
    count(*) AS recent_matches,
    count(*) FILTER (WHERE (result = 'W'::text)) AS recent_wins,
    count(*) FILTER (WHERE (result = 'L'::text)) AS recent_losses,
    round(((100.0 * (count(*) FILTER (WHERE (result = 'W'::text)))::numeric) / (count(*))::numeric), 2) AS recent_win_rate
   FROM ranked_matches
  WHERE (match_rank <= 10)
  GROUP BY player_id, player_name;


ALTER VIEW public.v_player_recent_form OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 24719)
-- Name: v_player_round_performance; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_player_round_performance AS
 SELECT p.player_id,
    p.player_name,
    v.round,
    count(*) AS total_matches,
    count(*) FILTER (WHERE (v.result = 'W'::text)) AS wins,
    count(*) FILTER (WHERE (v.result = 'L'::text)) AS losses,
    round(((100.0 * (count(*) FILTER (WHERE (v.result = 'W'::text)))::numeric) / (count(*))::numeric), 2) AS win_rate
   FROM (public.v_player_matches v
     JOIN public.dim_player p ON ((v.player_id = p.player_id)))
  GROUP BY p.player_id, p.player_name, v.round;


ALTER VIEW public.v_player_round_performance OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 24714)
-- Name: v_player_tier_performance; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_player_tier_performance AS
 SELECT p.player_id,
    p.player_name,
    t.tier,
    count(*) AS total_matches,
    count(*) FILTER (WHERE (v.result = 'W'::text)) AS wins,
    count(*) FILTER (WHERE (v.result = 'L'::text)) AS losses,
    round(((100.0 * (count(*) FILTER (WHERE (v.result = 'W'::text)))::numeric) / (count(*))::numeric), 2) AS win_rate
   FROM ((public.v_player_matches v
     JOIN public.dim_player p ON ((v.player_id = p.player_id)))
     JOIN public.dim_tournament t ON ((v.tournament_id = t.tournament_id)))
  GROUP BY p.player_id, p.player_name, t.tier;


ALTER VIEW public.v_player_tier_performance OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 24704)
-- Name: v_player_yearly_performance; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_player_yearly_performance AS
 SELECT p.player_id,
    p.player_name,
    d.year,
    count(*) AS total_matches,
    count(*) FILTER (WHERE (v.result = 'W'::text)) AS wins,
    count(*) FILTER (WHERE (v.result = 'L'::text)) AS losses,
    round(((100.0 * (count(*) FILTER (WHERE (v.result = 'W'::text)))::numeric) / (count(*))::numeric), 2) AS win_rate
   FROM ((public.v_player_matches v
     JOIN public.dim_player p ON ((v.player_id = p.player_id)))
     JOIN public.dim_date d ON ((v.date_id = d.date_id)))
  GROUP BY p.player_id, p.player_name, d.year;


ALTER VIEW public.v_player_yearly_performance OWNER TO postgres;

--
-- TOC entry 4933 (class 2606 OID 24654)
-- Name: dim_date dim_date_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_date
    ADD CONSTRAINT dim_date_pkey PRIMARY KEY (date_id);


--
-- TOC entry 4925 (class 2606 OID 24627)
-- Name: dim_player dim_player_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_player
    ADD CONSTRAINT dim_player_pkey PRIMARY KEY (player_id);


--
-- TOC entry 4927 (class 2606 OID 24629)
-- Name: dim_player dim_player_player_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_player
    ADD CONSTRAINT dim_player_player_name_key UNIQUE (player_name);


--
-- TOC entry 4929 (class 2606 OID 24638)
-- Name: dim_tournament dim_tournament_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_tournament
    ADD CONSTRAINT dim_tournament_pkey PRIMARY KEY (tournament_id);


--
-- TOC entry 4931 (class 2606 OID 24640)
-- Name: dim_tournament dim_tournament_tournament_name_tier_host_location_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_tournament
    ADD CONSTRAINT dim_tournament_tournament_name_tier_host_location_key UNIQUE (tournament_name, tier, host_location);


--
-- TOC entry 4935 (class 2606 OID 24673)
-- Name: fact_matches fact_matches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_matches
    ADD CONSTRAINT fact_matches_pkey PRIMARY KEY (match_id);


--
-- TOC entry 4936 (class 2606 OID 24674)
-- Name: fact_matches fk_match_date; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_matches
    ADD CONSTRAINT fk_match_date FOREIGN KEY (date_id) REFERENCES public.dim_date(date_id);


--
-- TOC entry 4937 (class 2606 OID 24679)
-- Name: fact_matches fk_match_tournament; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_matches
    ADD CONSTRAINT fk_match_tournament FOREIGN KEY (tournament_id) REFERENCES public.dim_tournament(tournament_id);


--
-- TOC entry 4938 (class 2606 OID 24684)
-- Name: fact_matches fk_player1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_matches
    ADD CONSTRAINT fk_player1 FOREIGN KEY (player1_id) REFERENCES public.dim_player(player_id);


--
-- TOC entry 4939 (class 2606 OID 24689)
-- Name: fact_matches fk_player2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_matches
    ADD CONSTRAINT fk_player2 FOREIGN KEY (player2_id) REFERENCES public.dim_player(player_id);


--
-- TOC entry 4940 (class 2606 OID 24694)
-- Name: fact_matches fk_winner_player; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_matches
    ADD CONSTRAINT fk_winner_player FOREIGN KEY (winner_player_id) REFERENCES public.dim_player(player_id);


-- Completed on 2026-11-11 15:09:16

--
-- PostgreSQL database dump complete
--

\unrestrict MMjYd2oqhhDEZ5EjdbWg06g8mE8LCWleMfNWgvNwntgEMVAjC3WEkajXnCbhMMU

