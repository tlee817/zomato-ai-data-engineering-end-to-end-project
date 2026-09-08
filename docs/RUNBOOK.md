# Setup runbook

Step-by-step infrastructure setup for the pipeline described in the [README](../README.md).
Run the SQL in Snowsight as `ACCOUNTADMIN`, interleaved with the AWS console steps.

Every environment-specific value in the SQL and JSON is a placeholder — `<BUCKET>`, `<ROLE_ARN>`,
`<ACCOUNT_ID>`, `<STORAGE_AWS_IAM_USER_ARN>`, `<STORAGE_AWS_EXTERNAL_ID>`. Substitute them locally;
real values belong in `.env`, which is gitignored.

---

## 1. Create the Snowflake objects

`snowflake_scripts/01_setup.sql` — warehouse `ZOMATO_WH` (XSMALL, 60s auto-suspend to conserve
trial credits), database `ZOMATO`, the medallion schemas, and `DBT_ROLE` with grants on the
warehouse and database.

## 2. Create the S3 bucket and IAM role (AWS)

Create the bucket, then an IAM role for Snowflake with:

- **Trust policy** — `aws/iam/snowflake-role-trust-policy-initial.json`. A placeholder that trusts
  your own account root, because the Snowflake principal doesn't exist yet.
- **Permission policy** — `aws/iam/s3-read-policy.json`. `GetObject` / `ListBucket` scoped to the
  bucket.

## 3. Create the storage integration

`snowflake_scripts/02_storage_integration.sql` — fill in the role ARN and bucket, run
`CREATE STORAGE INTEGRATION`, then `DESC INTEGRATION` and copy out two values:
`STORAGE_AWS_IAM_USER_ARN` and `STORAGE_AWS_EXTERNAL_ID`.

## 4. Finalise the trust policy (AWS)

Replace the role's trust policy with `aws/iam/snowflake-role-trust-policy-final.json`, substituting
the two values from step 3. This completes the handshake: Snowflake's IAM user becomes the trusted
principal, and the external ID prevents the confused-deputy problem.

## 5. Create the stage and file format

`snowflake_scripts/03_stage_and_formats.sql` — defines `CSV_FMT` (header skipped, quoted fields,
lenient column counts) and the external stage over `s3://<BUCKET>/raw/`. The closing `LIST`
confirms Snowflake can see the files, which is the real test that steps 2–4 worked.

## 6. Upload the CSVs

One file per prefix under `raw/`: `restaurants/`, `users/`, `food/`, `menu/`, `orders/`,
`order_items/`, `reviews/`.

> The `COPY INTO` prefixes in `05_copy_into.sql` must match the S3 prefixes exactly. A prefix that
> matches no files does not raise an error — `COPY INTO` reports success having loaded zero files.

## 7. Create and load the RAW tables

`snowflake_scripts/04_raw_tables.sql`, then `snowflake_scripts/05_copy_into.sql`.

Dimension files load as all-`STRING` columns with `ON_ERROR = 'CONTINUE'` to tolerate malformed
rows; fact files load with `ON_ERROR = 'ABORT_STATEMENT'` to keep counts exact. The script ends
with a row-count check. Expected:

| Table | Rows |
| --- | --- |
| `order_items` | 22,998,179 |
| `orders` | 10,000,000 |
| `menu` | 1,179,936 |
| `food` | 371,561 |
| `reviews` | 300,000 |
| `restaurants` | 148,541 |
| `users` | 100,000 |

---

## 8. Run dbt

```bash
python3.11 -m venv .venv && .venv/bin/pip install -r requirements.txt
cp .env.example .env            # fill in Snowflake + AWS values
set -a && source .env && set +a

cd zomato
../.venv/bin/dbt build
```

`zomato/profiles.yml` resolves every connection value through `env_var()`, so it reads from `.env`
with no credentials in the repo.

### Authentication note

If a connection **hangs** for ~100 seconds and then fails with
`250001: Could not connect to Snowflake backend`, that is a pending MFA push, not bad credentials —
approve it on your device. A genuinely wrong password fails in under a second with
`390100 Incorrect username or password`.

Because every dbt invocation opens a fresh connection and triggers a new push, password auth will
not survive the move to Airflow. Switch to key-pair auth before then — `zomato/profiles.yml`
carries a commented `private_key_path` block — or create a `TYPE = SERVICE` user, which is exempt
from MFA.
