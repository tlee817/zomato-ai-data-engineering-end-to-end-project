# Zomato AI Data Engineering — End-to-End Project

An end-to-end analytics pipeline over a Zomato food-delivery dataset:
**S3 → Snowflake → dbt → AI enrichment**, orchestrated with Airflow.

Built incrementally, one phase per set of commits.

---

## Architecture

Raw CSVs land in S3 and are loaded into Snowflake, which is organised as a medallion
architecture inside a single `ZOMATO` database:

| Schema      | Purpose                                            |
| ----------- | -------------------------------------------------- |
| `BRONZE`    | Iceberg tables written by Spark (dbt sources)       |
| `RAW`       | Direct `COPY INTO` landing zone from the S3 stage   |
| `STAGING`   | Cleaned and conformed models (dbt)                  |
| `MARTS`     | Gold-layer facts and dimensions (dbt)               |
| `SNAPSHOTS` | SCD Type-2 history (dbt)                            |
| `AI`        | LLM-enriched tables (review sentiment, topics)      |

Snowflake reads S3 through a **storage integration** rather than access keys: Snowflake assumes
a dedicated IAM role via `sts:AssumeRole` guarded by an external ID, so **no AWS credentials are
ever stored in Snowflake**.

Compute is a single `XSMALL` warehouse with 60-second auto-suspend, sized to keep trial credit
burn low.

---

## Project status

- [x] **Phase 2 — Warehouse & S3 ingestion**: Snowflake warehouse, database, medallion schemas,
      `DBT_ROLE`, S3 storage integration, external stage, RAW tables, and `COPY INTO` loads
- [ ] Phase 3 — Spark / Iceberg bronze layer
- [ ] Phase 4 — dbt staging, marts, snapshots, and tests
- [ ] Phase 5 — AI enrichment over review text
- [ ] Phase 6 — Airflow orchestration
- [ ] Phase 7 — BI dashboard

---

## Phase 2 runbook

Run the SQL in Snowsight as `ACCOUNTADMIN`, interleaved with the AWS console steps below.

**1. Create Snowflake objects** — `snowflake_scripts/01_setup.sql`
Creates warehouse `ZOMATO_WH`, database `ZOMATO`, the six schemas above, and `DBT_ROLE`
with grants on the warehouse and database.

**2. Create the S3 bucket and IAM role (AWS)**
Create a bucket, then an IAM role named `snowflake-zomato-role` with:
- Trust policy: `aws/iam/snowflake-role-trust-policy-initial.json` — a placeholder that trusts your
  own account root, because the real Snowflake principal doesn't exist yet.
- Permission policy: `aws/iam/s3-read-policy.json` — `GetObject`/`ListBucket` scoped to the bucket.

**3. Create the storage integration** — `snowflake_scripts/02_storage_integration.sql`
Fill in the role ARN and bucket, run `CREATE STORAGE INTEGRATION`, then run `DESC INTEGRATION`
and copy two values out of the result: `STORAGE_AWS_IAM_USER_ARN` and `STORAGE_AWS_EXTERNAL_ID`.

**4. Finalise the trust policy (AWS)**
Replace the role's trust policy with `aws/iam/snowflake-role-trust-policy-final.json`, substituting
the two values from step 3. This is what completes the handshake — Snowflake's IAM user becomes the
trusted principal, and the external ID prevents the confused-deputy problem.

**5. Create the stage and file format** — `snowflake_scripts/03_stage_and_formats.sql`
Defines `CSV_FMT` (header skipped, quoted fields, lenient column counts) and the external stage
pointing at `s3://<BUCKET>/raw/`. The closing `LIST` confirms Snowflake can see the files.

**6. Upload the CSVs to S3**
One file per prefix under `raw/`: `restaurants/`, `users/`, `food/`, `menu/`, `orders/`,
`order_items/`, `reviews/`.

**7. Create and load the RAW tables** — `snowflake_scripts/04_raw_tables.sql`, then
`snowflake_scripts/05_copy_into.sql`
The four dimension files are messy real-world exports, so they load as all-`STRING` columns with
`ON_ERROR = 'CONTINUE'` to skip bad rows. The three generated fact files are clean and typed, so
they load with `ON_ERROR = 'ABORT_STATEMENT'` to keep row counts exact. `05_copy_into.sql` ends
with a row-count check across all seven tables.

---

## Configuration

Every environment-specific value in the SQL and JSON is a placeholder — `<BUCKET>`, `<ROLE_ARN>`,
`<ACCOUNT_ID>`, `<STORAGE_AWS_IAM_USER_ARN>`, `<STORAGE_AWS_EXTERNAL_ID>`. Substitute them locally.
Real account IDs, ARNs, and credentials live in a local `.env`, which is gitignored and never
committed.

## Data

The source CSVs are not versioned here — `data/` is gitignored (roughly 3 GB). Download the dataset
from the upstream project this build follows,
[darshilparmar/zomato-ai-data-engineering-end-to-end-project](https://github.com/darshilparmar/zomato-ai-data-engineering-end-to-end-project),
and unpack it into `data/` before running the S3 upload step.

## Repository layout

```
aws/iam/                 IAM permission and trust policies for the storage integration
snowflake_scripts/       Phase 2 setup SQL, numbered in run order
data/                    Local source CSVs (gitignored)
```
