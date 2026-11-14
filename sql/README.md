# Badminton Analytics — PostgreSQL SQL portfolio

This folder contains **organized SQL recovered from the user's original DBeaver workflow**.
The unchanged source is preserved as `archive/02_original_sql_workflow.sql` (1,359 lines).

## Contents

| File | Purpose | Execution |
| --- | --- | --- |
| `02a_staging_setup.sql` | Final staging-table definition | Fresh database only |
| `02b_data_cleaning.sql` | Validate and convert `DD-MM-YYYY` strings to PostgreSQL dates | After curated CSV import, fresh stage only |
| `03_warehouse_load.sql` | One-time construction and population of player, tournament, date and match tables | Fresh database only |
| `04_analytical_views.sql` | Recreate all 12 analytical views in dependency order | Fresh database only |
| `05_data_validation.sql` | Read-only match, quality, integrity and player-count reconciliation | Read-only; suitable for existing DB |
| `archive/02_original_sql_workflow.sql` | Exact, unmodified development history | Archive only — **do not execute end to end** |

**Note:** The user's local `01_database_schema.sql` backup was not uploaded and is therefore **not included** in this package. It is a snapshot of the finished schema and should be preserved separately. Restoring that dump and also executing the creation scripts in this package in the same database would cause object-already-exists errors.

## Rebuild sequence (new, empty PostgreSQL database only)

1. Run `02a_staging_setup.sql`.
2. Import the **curated** 2018–2025 match CSV into `stg_matches` using DBeaver's import wizard. Map all 12 source fields; `date` is a text column.
3. Run `02b_data_cleaning.sql` and verify row count and parsed dates. The original curated staging table had **10,444 rows**.
4. Run `03_warehouse_load.sql` **once** to populate the three dimensions and the fact table.
5. Run `04_analytical_views.sql` **once** to create analytical views.
6. Run `05_data_validation.sql` and investigate deviations from the expected counts.

**Do not run steps 1–5 against the existing `badminton_analytics` database.** For your existing database, only the read-only validation file is intended for execution.

## Warehouse architecture

- `stg_matches`: imported curated match rows, including text `date` and transformed `match_date`.
- `dim_player`: one player per row, unique `player_name`.
- `dim_tournament`: tournament name, tier and host location.
- `dim_date`: dates between January 1, 2018 and December 31, 2025.
- `fact_matches`: one unique match per row; links to players, tournament and date.
- `v_player_matches`: two records per match, one from each player's perspective; useful for player filters and win/loss calculations, **not** naive dataset-wide match totals.

### Views recovered

- `v_player_matches`
- `v_player_yearly_performance`
- `v_player_head_to_head`
- `v_player_tier_performance`
- `v_player_round_performance`
- `v_match_score_parsed`
- `v_match_quality`
- `v_player_match_features`
- `v_player_advanced_kpis`
- `v_player_recent_form`
- `v_player_last10_matches`
- `v_player_home_performance`

The views support yearly/tier/round performance, opponent scouting, score quality, per-game features, recent form and home/away analyses.

## Previously checked project numbers

| Object or measurement | Expected |
| --- | ---: |
| Staging rows | 10,444 |
| `dim_player` | 1,047 |
| `dim_tournament` | 246 |
| `dim_date` | 2,922 |
| `fact_matches` | 10,444 |
| `v_player_matches` | 20,888 |
| Complete match scores | 10,245 |
| Incomplete match scores | 199 |
| Anthony Sinisuka GINTING: matches | 250 |
| Anthony Sinisuka GINTING: wins | 157 |
| Anthony Sinisuka GINTING: losses | 93 |

These numbers are historical project validations, **not values recomputed by this static archive review**. Run the validation queries against PostgreSQL to reproduce them.

## Scope and limitations

- The recovered SQL is **not the complete original CSV/Excel/Power Query cleaning pipeline**. Earlier manual cleaning, deduplication, row exclusion, source-file conversion and the selected 2018–2025 scope took place before the curated records were imported and are not reproduced here.
- The original workflow tried **three staging-table definitions** and included `DROP TABLE`, `TRUNCATE TABLE` and duplicated dimension inserts. Those experimental statements are retained only in the unmodified archive; they are excluded from the organized build scripts.
- Date standardization and `TRIM()` of names/tournament fields are the directly documented preparation operations in the saved SQL. `v_match_quality` **classifies** complete versus incomplete score strings; it does not repair invalid source scores.
- The original `v_match_score_parsed` casts split score fragments to `SMALLINT`; unexpected non-numeric scores could make it fail on a different raw dataset. The curated input is a prerequisite.
- No raw dataset, credentials or Power BI `.pbix` were included in the uploaded `.sql` file. The report's DAX is stored separately in the user's local PBIX and is not reconstructed in this bundle.
- The `01_database_schema.sql` schema-only dump is a backup reference, not a substitute for a reproducible source-data import and ETL pipeline.
- Do not interpret these 10,444 records as a comprehensive population of all BWF men's singles matches worldwide; they describe the curated project dataset.

## Source and review integrity

All **12 analytical-view definitions** were copied from the saved SQL without substantive rewriting. Warehouse DDL and DML were copied from the successful definitions while removing repeated trial attempts. Validation checks are tagged as either recovered or newly added. The package was organized and checked statically, **not executed against a PostgreSQL instance**.
