-- =====================================================================
-- Phase 2 · Step 2 — Secure S3 <-> Snowflake link (Storage Integration)
-- This is the real-world way to connect (no keys stored in Snowflake).
--
-- ORDER OF OPERATIONS (see docs/RUNBOOK.md for the AWS clicks):
--   A. In AWS IAM, create role `snowflake-zomato-role` with a PLACEHOLDER
--      trust policy (trust your own account for now).
--   B. Run CREATE STORAGE INTEGRATION below with that role's ARN.
--   C. DESC INTEGRATION -> copy STORAGE_AWS_IAM_USER_ARN + EXTERNAL_ID.
--   D. Edit the IAM role's trust policy with those two values.
-- =====================================================================
USE ROLE ACCOUNTADMIN;

-- >>> EDIT THESE TWO <<<
--   <ROLE_ARN> = arn:aws:iam::<your-account-id>:role/snowflake-zomato-role
--   <BUCKET>   = your bucket, e.g. zomato-dl-yourname
CREATE OR REPLACE STORAGE INTEGRATION ZOMATO_S3_INT
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = '<ROLE_ARN>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<BUCKET>/');

GRANT USAGE ON INTEGRATION ZOMATO_S3_INT TO ROLE DBT_ROLE;

-- Run this, then copy the two values into the IAM role trust policy (Step D).
DESC INTEGRATION ZOMATO_S3_INT;
--   STORAGE_AWS_IAM_USER_ARN  ->  the "AWS": principal in the trust policy
--   STORAGE_AWS_EXTERNAL_ID   ->  the sts:ExternalId condition