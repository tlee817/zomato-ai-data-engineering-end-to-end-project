-- =====================================================================
-- Phase 2 · Step 3 — External stage on S3 + CSV file format
-- =====================================================================
USE ROLE ACCOUNTADMIN;
USE DATABASE ZOMATO;
USE SCHEMA RAW;

-- Plain CSV (manual upload, no gzip). Files KEEP their header row -> SKIP_HEADER = 1.
-- Comment fields (reviews) contain commas but are quoted, so keep the quote char.
CREATE OR REPLACE FILE FORMAT ZOMATO.RAW.CSV_FMT
  TYPE = 'CSV'
  COMPRESSION = 'AUTO'                       -- plain CSV (also fine if you ever switch to .gz)
  FIELD_DELIMITER = ','
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1                            -- skip the header row your CSVs still have
  EMPTY_FIELD_AS_NULL = TRUE
  NULL_IF = ('', '\\N', 'NULL')
  TRIM_SPACE = FALSE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;   -- messy source rows (e.g. food.csv missing a
                                            -- trailing field) NULL-fill instead of aborting

-- >>> EDIT <BUCKET> <<<
-- Upload one CSV per folder:  raw/restaurants/  raw/users/  raw/food/  raw/menu/
--                             raw/orders/  raw/order_items/  raw/reviews/
CREATE OR REPLACE STAGE ZOMATO.RAW.ZOMATO_RAW_STAGE
  STORAGE_INTEGRATION = ZOMATO_S3_INT
  URL = 's3://<BUCKET>/raw/'
  FILE_FORMAT = ZOMATO.RAW.CSV_FMT;

-- Confirm Snowflake can see your files (should list the seven table folders).
LIST @ZOMATO.RAW.ZOMATO_RAW_STAGE;