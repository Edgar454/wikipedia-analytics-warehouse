# Wikipedia Analytics Warehouse
## A Production-Grade Analytical Pipeline on BigQuery + dbt + Airflow + Power BI

---

## Overview

This project builds a full analytical warehouse on top of two public BigQuery datasets:

- **Wikipedia pageviews 2026** — 21.9 billion rows, 929GB, updated hourly. The engineering gym — every bad habit gets punished at scale.
- **thelook_ecommerce** — synthetic retail dataset. The LinkedIn showcase — clean dimensional model for business reporting.

Both domains live in a single dbt monorepo, sharing macros, conventions, and infrastructure.

---

## Stack

| Tool | Role | Notes |
|---|---|---|
| BigQuery (Sandbox) | Data warehouse / compute engine | 1TB/month free query tier, 10GB storage |
| dbt 1.11 | Transformation layer | Models, tests, documentation, lineage |
| Airflow | Orchestration | DAG design complete, deployment pending billing |
| Power BI | Reporting / visualization | Connected via OAuth to BigQuery |

---

## Repository Structure

```
wikipedia/
├── models/
│   ├── wikipedia/
│   │   ├── staging/
│   │   │   ├── schema.yml
│   │   │   ├── sources/
│   │   │   │   ├── stg_pageviews_raw.sql
│   │   │   │   └── stg_wikidata_raw.sql
│   │   │   ├── stg_pageviews.sql
│   │   │   └── stg_wikidata.sql
│   │   ├── intermediate/
│   │   │   ├── schema.yml
│   │   │   ├── int_pageviews_classified.sql
│   │   │   ├── int_wikidata_instance_of.sql
│   │   │   ├── int_structural_entities.sql
│   │   │   └── bridge_entity_sitelinks.sql
│   │   └── marts/
│   │       ├── schema.yml
│   │       ├── dim_date.sql
│   │       ├── dim_entity.sql
│   │       ├── dim_entity_type.sql
│   │       ├── fact_pageviews.sql
│   │       └── gold_pageviews_enriched.sql
│   └── ecommerce/
│       ├── staging/
│       ├── intermediate/
│       └── marts/
├── seeds/
│   ├── schema.yml
│   ├── dim_languages.csv
│   └── structural_roots.csv
└── dbt_project.yml
```

---

## Data Sources

### Wikipedia pageviews_2026
**Grain:** one row per `wiki` + `title` + `datehour`
**Size:** 21.9 billion rows, 929GB — a naive full scan costs your entire monthly free tier

| Column | Type | Description |
|---|---|---|
| datehour | TIMESTAMP | Partition column — always filter on this |
| wiki | STRING | Language community (en, fr.m, ja, zh...) |
| title | STRING | URL-encoded Wikipedia title |
| views | INT64 | HTTP requests to this URL in this hour |

**Key insight:** a pageview is an HTTP request, not a reading session. One user intent generates multiple pageviews (search + article click).

### Wikidata
**Size:** 90.7 million entities, 1.58TB
**Snapshot date:** May 13, 2026

The universal knowledge graph. Contains entity metadata for every notable Wikipedia subject — people, places, films, albums, organizations. Connected to pageviews via `en_wiki = title` (English) or `sitelinks` (multilingual).

**Important:** Wikidata uses two entity types sharing the same numeric ID space — Q items (real-world entities) and P properties (relationship types). All pipeline models filter to `type = 'item'` via `stg_wikidata` to exclude properties.

---

## Pipeline Architecture

```
SOURCES
├── pageviews_2026          (21.9B rows, partitioned by datehour)
└── wikidata                (90.7M entities, 1.58TB)

STAGING
├── stg_pageviews_raw       view — partition filter, 3-day window for late data
├── stg_wikidata_raw        view — column selection, adds first_seen_in_pipeline
├── stg_pageviews           view — removes garbage rows (-, Index.php)
└── stg_wikidata            view — filters to type = 'item' only (canonical wikidata source)

INTERMEDIATE
├── int_pageviews_classified    view — adds page_type classification
├── int_wikidata_instance_of    view — unnests instance_of arrays (Q items only)
├── int_structural_entities     view — flags structural entity types via subclass graph
└── bridge_entity_sitelinks     table — exploded sitelinks for multilingual title matching

DIMENSIONS
├── dim_date                table — hourly date spine 2025-2026
├── dim_entity              view — entity descriptive attributes
├── dim_entity_type         table — entity type labels and flags
└── dim_languages           seed — wiki codes, language names, mobile flags

GOLD
└── gold_pageviews_enriched     view — fully joined, Power BI source

MARTS (Power BI consumption layer — pending)
├── mart_trends_daily           table — views by entity type and date
├── mart_language_daily         table — views by language community and date
└── mart_entity_daily           table — top entities by day
```

---

## Key Engineering Decisions

### Multilingual matching via sitelinks
Initial approach joined `pageviews.title = wikidata.en_wiki` — achieved 87% match rate for English but near-zero for non-Latin scripts (Japanese 2.3%, Chinese 3.9%, Russian 8%).

Replaced with `bridge_entity_sitelinks` — an exploded sitelinks table covering all language Wikipedia titles per entity. Match rates after:

| Language | Before | After |
|---|---|---|
| English | 87.85% | 88.52% |
| French | 46.35% | 89.98% |
| Japanese | 2.31% | 93.33% |
| Chinese | 3.86% | 71.46% |
| Russian | 7.95% | 83.65% |

### Q items vs P properties
Wikidata uses the same numeric ID space for Q items (entities: people, places, films) and P properties (relationship types: date of birth, country). Q5 and P5 are completely different things sharing numeric_id = 5. All models reference `stg_wikidata` which filters `WHERE type = 'item'`, ensuring properties never contaminate entity resolution or dimension joins.

### Snowflake schema (justified)
Pure star schema would have required joining wikidata directly at query time — 1.58TB scan on every Power BI refresh. The bridge table adds one join but enables multilingual enrichment and eliminates the expensive source scan from the query path.

### page_type classification
Rather than filtering noise (Special:Search, translated search pages across all languages), rows are classified by `page_type`:

| page_type | Description |
|---|---|
| article | Real Wikipedia content page |
| namespace | Any title containing `:` — catches all language search pages |
| wikiquote | `.q` wiki suffix |
| wiktionary | `.d` wiki suffix |
| mediawiki | `.w` wiki suffix |
| donation | `thankyou*` wikis |
| commons | Wikimedia Commons |
| portal | `www.*` wikis |

Data is never deleted — Power BI filters on `page_type = 'article'` at query time.

### Entity type label resolution
`dim_entity_type.type_label` uses COALESCE across languages (en → fr → de → es → ja → Q{id}) because ~140 entity types have no English label in Wikidata but are documented in other languages. Fallback to Q-number ensures `type_label` is never null.

### Multilingual en_wiki duplicates
Multiple Wikidata entities can point to the same Wikipedia page (e.g. species reclassification — both old and new Q entries claim the same `en_wiki`). This is a valid Wikidata situation, not a pipeline error. `en_wiki` is not tested for uniqueness in `dim_entity`.

### Incremental models (designed, not deployed)
All models are designed as incremental with proper `is_incremental()` guards and safety windows. Commented out due to BigQuery sandbox DML restriction. Switch to incremental materialization when billing is enabled.

### Gold layer as view, marts as tables
`gold_pageviews_enriched` at raw grain is too large to materialize (3 days of global pageviews exceeds 10GB sandbox storage). Kept as a view for engineering use. Power BI reads pre-aggregated mart tables instead — correct production pattern regardless of the storage constraint.

---

## Testing

78 data tests across all layers. Run with:

```bash
dbt test                          # all tests
dbt test --select staging         # staging only
dbt test --select dim_entity_type # single model
```

### Test coverage by layer

**Seeds**
- `dim_languages` — unique + not_null on wiki_code, accepted_values on is_mobile
- `structural_roots` — unique + not_null on numeric_id

**Staging**
- `stg_pageviews_raw` / `stg_pageviews` / `stg_wikidata` — not_null on all key columns
- `stg_wikidata_raw` — unique on id, composite uniqueness on (type, numeric_id) via dbt_utils
- `stg_wikidata` — unique on id and numeric_id (safe after type = 'item' filter)

**Intermediate**
- `int_pageviews_classified` — not_null on all columns, accepted_values on page_type
- `int_wikidata_instance_of` — not_null on en_wiki and numeric_id
- `bridge_entity_sitelinks` — not_null on numeric_id, wiki_code, site, title

**Marts**
- `dim_date` — unique + not_null on date_id and datehour
- `dim_entity_type` — unique + not_null on numeric_id, accepted_values on boolean flags
- `fact_pageviews` — not_null on all columns, accepted_values on page_type
- `gold_pageviews_enriched` — not_null on key columns, accepted_values on is_matched and page_type

### Key test decisions
- `en_wiki` not tested for uniqueness — multiple Q items can share a Wikipedia page (valid Wikidata state)
- `type_label` not tested for not_null — ~140 types have no English label but are valid entities
- `numeric_id` not tested for uniqueness in `stg_wikidata_raw` — Q and P share numeric IDs; tested via composite key instead

---

## Known Limitations

### Temporal inconsistency (SCD problem)
Wikidata is a May 2026 snapshot joined against historical pageviews. Entity metadata reflects current state, not state at time of pageview. No solution available with this data source — documented limitation.

### Notability gap
12% of clean English pageviews remain unmatched — real Wikipedia articles about sub-notable people and recent events not yet in Wikidata. Structurally unfixable. Captured separately as demand signal: pages people read that the knowledge graph hasn't catalogued yet.

### Late-arriving data
Wikipedia pageviews are published with a 2-day lag. Pipeline uses a 3-day lookback window to ensure latest available partition is always captured. In production, an Airflow sensor would wait for partition availability before triggering transformations.

### Sandbox DML restriction
BigQuery sandbox does not support DML queries (INSERT, UPDATE, MERGE) without billing enabled. Incremental materialization is unavailable. All models fall back to full table or view materialization.

### Storage constraint
BigQuery sandbox provides 10GB free storage. Raw grain gold table (~6GB for 1 day) leaves insufficient headroom for all materialized models simultaneously. Solution: materialize aggregated marts only, keep raw grain as views.

---

## Cost Management

| Query type | Estimated cost |
|---|---|
| One hour partition (pageviews_2026) | ~5.27 GB |
| Full wikidata scan (key columns) | ~6-8 GB |
| bridge_entity_sitelinks build | ~3.61 GB (one-time) |
| dim_entity_type build | ~6.42 GB (one-time) |
| gold_pageviews_enriched (view, 1 day) | ~9.1 GB per query |
| Monthly free tier | 1,000 GB |

**Total consumed during development:** ~38 GB

**Rules:**
- Always filter `datehour` before querying pageviews
- Never include `labels`, `aliases`, or `item` columns — 14.5GB minimum floor
- Use `TABLESAMPLE` for wikidata exploration
- Use `INFORMATION_SCHEMA` for schema inspection — free
- Monitor daily consumption via `INFORMATION_SCHEMA.JOBS_BY_PROJECT`
- Never run `dbt run --full-refresh` on bridge_entity_sitelinks or dim_entity_type accidentally — protect with `+full_refresh: false` in dbt_project.yml

---

## Analytical Marts (Planned)

| Mart | Business Question |
|---|---|
| Trends | What is the world reading, when, at what scale? |
| Cross-language | How does content propagate across language communities? |
| Demand gaps | What are people reading that Wikidata hasn't catalogued yet? |

All three marts are queries on the same snowflake schema. The demand gaps mart is the most original — it surfaces pages with high traffic but no structured knowledge graph entry, identifying emerging topics before they reach mainstream awareness.

---

## Roadmap

| Version | Scope | Status |
|---|---|---|
| v1 | End-to-end pipeline, data flows, Power BI connected | ✅ Complete |
| v2 | dbt tests, data quality assertions, schema documentation | ✅ Complete |
| v3 | dbt lineage documentation, dbt docs serve | Next |
| v4 | Airflow orchestration, DAG deployment | Pending billing |
| v5 | Observability — cost per model, freshness monitoring, pipeline tracing | Future |

---

## Setup

### Prerequisites
- Python 3.11+
- Google Cloud SDK
- dbt-bigquery
- dbt-utils package

### Installation

```bash
python -m venv env
env\Scripts\activate          # Windows
pip install dbt-bigquery
```

### Authentication

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
```

### Configuration
Create `~/.dbt/profiles.yml`:

```yaml
wikipedia:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: YOUR_PROJECT_ID
      dataset: dbt_dev
      location: US
      threads: 4
      maximum_bytes_billed: 10000000000
```

### Run

```bash
cd wikipedia
dbt debug          # validate connection
dbt deps           # install dbt_utils package
dbt seed           # load dim_languages and structural_roots
dbt run            # build all models
dbt test           # run all tests
dbt docs generate  # generate lineage documentation
dbt docs serve     # open lineage graph in browser
```

### Selective runs

```bash
# Run a single model
dbt run --select gold_pageviews_enriched

# Run a model and all its upstream dependencies
dbt run --select +gold_pageviews_enriched

# Run expensive one-time tables manually
dbt run --select bridge_entity_sitelinks --full-refresh
dbt run --select dim_entity_type --full-refresh

# Test a specific layer
dbt test --select staging
dbt test --select marts
```

---

## Design Philosophy

- Every addition justified by operational need
- Complexity introduced incrementally
- Cost treated as a first-class constraint
- Observability as important as transformation
- Maintainability over sophistication
- No data deleted — classify and filter at consumption layer
- Tests document intent, not just correctness — test decisions are as important as the tests themselves