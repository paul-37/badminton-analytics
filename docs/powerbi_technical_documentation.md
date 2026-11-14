# Badminton Analytics — Power BI Technical Documentation

**Project:** Badminton Analytics (Men's Singles, 2018–2025)  
**Technology:** PostgreSQL, Power BI Desktop, DAX  
**Purpose:** Document the Power BI semantic model, calculations, report design, and validation checks for portfolio review.

> **Scope and interpretation:** The 10,444 matches below represent records in the project's curated dataset, not a complete census of all international badminton matches. Tournament/year distributions describe dataset coverage.

## 1. Overview

The report enables interactive player performance analysis, head-to-head scouting, tournament analysis, two-player comparison, and dataset-wide quality/coverage review. The report contains **five pages**:

1. **Player Overview** — selected player's matches, wins, losses, win rate, tournament tier performance, yearly trends, recent matches, and home/away performance.
2. **Opponent Scouting** — selected player's head-to-head record against an opponent, win/loss split, individual match history, first/last meeting, and matches per year.
3. **Tournament Analysis** — tournaments played, match counts and win rates by tier, results by round, and seasonal performance.
4. **Player Comparison** — independent Player A/B selectors, eight KPI cards, match/win/loss comparison, and win-rate comparison by tournament tier.
5. **Insights & Trends** — dataset-level KPIs, matches by year and tournament tier, score completeness, and high-level dataset observations.

All five pages use a consistent red/charcoal design and page navigation buttons.

## 2. Source and grain

- PostgreSQL database: `badminton_analytics`.
- Warehouse match-level table: `fact_matches`, **10,444 unique matches**.
- Power BI's `v_player_matches`: **20,888 player-perspective records**, because each match appears once for each participant.
- `dim_player`: **1,047 players**.
- `dim_tournament`: **246 tournament records**.
- `dim_date`: calendar dimension used for season/year reporting.
- `public v_match_quality`: match-level score quality attributes, including `match_id` and `score_status`.

**Critical modelling rule:** Use the player-perspective table for player statistics; for dataset-wide match counts, use `DISTINCTCOUNT(v_player_matches[match_id])` to avoid counting both perspectives.

## 3. Power BI semantic model

The relationship audit in Power BI Desktop's **Manage relationships** showed eight relationships: **seven active and one inactive**. They are one-to-many, with single-direction filtering from the one-side dimension/view to the many-side table.

| One-side table | Many-side table | Join key | Status |
|---|---|---|---|
| `dim_player` | `v_player_matches` | `player_id` | Active |
| `dim_tournament` | `v_player_matches` | `tournament_id` | Active |
| `dim_date` | `v_player_matches` | `date_id` | Active |
| `dim_player` | `public v_player_head_to_head` | `player_id` | Active |
| `dim_player` | `public v_player_last10_matches` | `player_id` | Active |
| `dim_tournament` | `public v_player_last10_matches` | `tournament_id` | Active |
| `dim_tournament` | `public v_match_quality` | `tournament_id` | Active |
| `public v_match_quality` | `v_player_matches` | `match_id` | **Inactive** |

**Inactive relationship rationale:** A relationship between the two match-related views is available but left inactive. Both are also reached from `dim_tournament`, and activating an additional route may create competing filter paths. Current data-quality cards aggregate directly from `public v_match_quality`, so this join does not need to be active for those calculations. Review intentionally if a future measure requires player-specific score quality.

### Disconnected tables

- `Player A Selector` and `Player B Selector` each hold a copy of the player ID/name list and have no model relationships.
- `Comparison Metrics` is a three-row disconnected table containing `Total Matches`, `Wins`, `Losses`, plus a numeric sorting column.
- DAX measures use `SELECTEDVALUE`, `TREATAS`, and `REMOVEFILTERS` to apply Player A/B selections independently. `SWITCH` selects the metric displayed in comparison visuals.

**See:** `docs/powerbi_data_model.png` for the saved Power BI model screenshot, and `docs/powerbi_dax_measures.xlsx` for the full exported formula inventory.

## 4. Key DAX calculation patterns

The complete measure inventory contains **35 measures**. Representative formulas follow; these are examples from the saved model, not a substitute for the entire workbook.

### Base player performance

```dax
Total Matches = COUNTROWS(v_player_matches)

Wins =
CALCULATE(
    COUNTROWS(v_player_matches),
    v_player_matches[result] = "W"
)

Losses =
CALCULATE(
    COUNTROWS(v_player_matches),
    v_player_matches[result] = "L"
)

Win Rate % = DIVIDE([Wins], [Total Matches], 0)
```

These measures respond to the selected player's filter and relevant tournament/date slicers.

### Independent Player A comparison

```dax
Player A Total Matches =
VAR SelectedPlayer =
    SELECTEDVALUE('Player A Selector'[player_id])
RETURN
IF(
    ISBLANK(SelectedPlayer),
    BLANK(),
    CALCULATE(
        [Total Matches],
        REMOVEFILTERS(dim_player),
        TREATAS({ SelectedPlayer }, dim_player[player_id])
    )
)
```

The equivalent Player B measure uses `Player B Selector`. Each selection independently evaluates its corresponding measures without requiring relationships from the selector tables.

### Metric switching for clustered comparison

```dax
Player A Comparison Value =
SWITCH(
    SELECTEDVALUE('Comparison Metrics'[Metric]),
    "Total Matches", [Player A Total Matches],
    "Wins", [Player A Wins],
    "Losses", [Player A Losses],
    BLANK()
)
```

### Dataset-wide unique match count

```dax
Dataset Total Matches =
DISTINCTCOUNT(v_player_matches[match_id])
```

### Score completeness

```dax
Score Completeness % =
VAR CompleteMatches =
    CALCULATE(
        DISTINCTCOUNT('public v_match_quality'[match_id]),
        'public v_match_quality'[score_status] = "Complete"
    )
VAR TotalMatches =
    DISTINCTCOUNT('public v_match_quality'[match_id])
RETURN
    DIVIDE(CompleteMatches, TotalMatches, 0)
```

**Formatting:** Win-rate and score-completeness measures are displayed as percentages. The comparison design uses red for Player A and charcoal for Player B.

## 5. Verified analytical baselines

### Selected player checks

| Measure | Viktor AXELSEN | Anthony Sinisuka GINTING |
|---|---:|---:|
| Matches | 300 | 250 |
| Wins | 248 | 157 |
| Losses | 52 | 93 |
| Win rate | 82.67% | 62.80% |

A direct PostgreSQL query independently confirmed Anthony Ginting's **250 total rows**, **250 distinct matches**, and **157 wins**; an earlier reference to 248 Anthony matches was incorrect. Do not overwrite the correct values with the earlier number.

### Head-to-head check

Viktor AXELSEN vs Anthony Sinisuka GINTING: **16 matches, 12 wins, 4 losses, 75.00% win rate**. First meeting **14 September 2018**, last meeting **14 September 2024**.

### Dataset counts

| KPI | Value |
|---|---:|
| Unique matches | 10,444 |
| Player-perspective records | 20,888 |
| Distinct players | 1,047 |
| Tournaments | 246 |
| Complete scores | 10,245 |
| Incomplete scores | 199 |
| Score completeness | 98.09% |

The score completeness calculation is `10,245 / 10,444`.

### Matches by year

| Year | Matches |
|---|---:|
| 2018 | 1,696 |
| 2019 | 1,671 |
| 2020 | 274 |
| 2021 | 507 |
| 2022 | 994 |
| 2023 | 1,772 |
| 2024 | 1,774 |
| 2025 | 1,756 |
| **Total** | **10,444** |

### Matches by tournament tier

| Tier | Matches |
|---|---:|
| BWF Tour Super 100 | 3,394 |
| Super 300 | 2,608 |
| Super 500 | 1,983 |
| Super 750 | 1,075 |
| Super 1000 | 797 |
| Grade 1 | 470 |
| World Tour Finals | 117 |
| **Total** | **10,444** |

The two dataset-wide distributions were validated against SQL/Power BI checks, and all seven tier counts sum to 10,444.

## 6. Quality assurance undertaken

- Tested selected-player interactions on Player Overview and Tournament Analysis.
- Verified opponent selection, H2H KPI calculations, match history, and yearly matchup chart.
- Tested independent Player A and B selectors and their effect on both comparison charts.
- Verified dataset-wide KPI counts, year/tier distributions and score-status figures.
- Tested sidebar page navigation across the five report pages.
- Audited relationships, including the intentional inactive match-quality link.
- Cross-checked a player-level discrepancy directly in PostgreSQL.

**Note:** This documents reported/manual functional checks, not an automated test suite. Re-run these checks after major data refreshes or model changes.

## 7. Data limitations and interpretation

1. The dataset covers **2018–2025** and is not guaranteed to contain every official match in those years.
2. The 2020/2021 dips reflect **recorded dataset coverage**; they are not independently verified totals of worldwide badminton activity.
3. Some score records are incomplete or irregular (**199 incomplete**), so game-score-derived analysis must account for validity status.
4. Source cleaning included duplicate and format issues; retain original input data and cleaning documentation for reproducibility.
5. Player-performance comparisons reflect **observed matches in this dataset**, not necessarily all career matches or standardized strength-of-schedule ratings.
6. A saved `.pbix` may depend on local PostgreSQL connection settings. Reproducibility requires instructions for data sources and refresh configuration.

## 8. Repository organization

```text
badminton-analytics/
├── powerbi/
│   └── badminton_analytics_dashboard.pbix
├── sql/
│   ├── 01_database_schema.sql
│   ├── 02a_staging_setup.sql
│   ├── 02b_data_cleaning.sql
│   ├── 03_warehouse_load.sql
│   ├── 04_analytical_views.sql
│   ├── 05_data_validation.sql
│   └── archive/
├── docs/
│   ├── database_inventory.csv
│   ├── powerbi_data_model.png
│   ├── powerbi_dax_measures.xlsx
│   └── powerbi_technical_documentation.md
└── screenshots/
```

The original workflow and schema export are historical/structural evidence. The organized SQL scripts must be checked for execution order, source-file dependencies, and environment-specific paths before claiming a fully one-command reproducible setup.

## 9. Final portfolio checklist

- [x] Core Power BI measures and dashboards built
- [x] Five-page interactive navigation tested
- [x] Key SQL and DAX calculations documented
- [x] Main match and score-quality counts cross-checked
- [ ] Place this file and the DAX workbook under `docs/`
- [ ] Export and review full-resolution screenshots of each dashboard page
- [ ] Ensure SQL scripts are safe and reproducible on a clean database
- [ ] Create the top-level GitHub README with dashboard screenshots and setup steps
- [ ] Review files for personal information, local paths and credentials before publishing

