  -- =====================================================================
  -- Phase 2 · Step 4 — RAW tables (Path 1 batch, manual plain-CSV upload)
  -- Column ORDER matches the CSV files you upload, with headers skipped.
  -- NOTE: the four DIMENSION files (restaurant/users/food/menu) carry a leading
  -- unnamed index column, so their tables start with a throwaway `_idx` column.
  -- The fact files (orders/order_items/reviews) have no index column.
  -- =====================================================================
  USE ROLE ACCOUNTADMIN;
  USE DATABASE ZOMATO;
  USE SCHEMA RAW;

  -- restaurant.csv  (index col dropped):
  -- id,name,city,rating,rating_count,cost,cuisine,lic_no,link,address,menu
  CREATE OR REPLACE TABLE RAW.restaurants (
    _idx          STRING,                    -- leading index column in the CSV (ignored downstream)
    id            STRING, name        STRING, city    STRING, rating   STRING,
    rating_count  STRING, cost        STRING, cuisine STRING, lic_no   STRING,
    link          STRING, address     STRING, menu    STRING
  );

  -- users.csv: user_id,name,email,password,Age,Gender,Marital Status,
  --            Occupation,Monthly Income,Educational Qualifications,Family size
  CREATE OR REPLACE TABLE RAW.users (
    _idx STRING,                             -- leading index column in the CSV
    user_id STRING, name STRING, email STRING, password STRING, age STRING,
    gender STRING, marital_status STRING, occupation STRING, monthly_income STRING,
    education STRING, family_size STRING
  );

  -- food.csv: f_id,item,veg_or_non_veg
  CREATE OR REPLACE TABLE RAW.food (
    _idx STRING,                             -- leading index column in the CSV
    f_id STRING, item STRING, veg_or_non_veg STRING
  );

  -- menu.csv: ,menu_id,r_id,f_id,cuisine,price
  CREATE OR REPLACE TABLE RAW.menu (
    _idx STRING,                             -- leading index column in the CSV
    menu_id STRING, r_id STRING, f_id STRING, cuisine STRING, price STRING
  );

  -- generated/orders.csv (clean, typed):
  CREATE OR REPLACE TABLE RAW.orders (
    order_id          NUMBER,
    order_timestamp   TIMESTAMP_NTZ,
    order_date        DATE,
    user_id           NUMBER,
    r_id              NUMBER,
    restaurant_city   STRING,
    cuisine           STRING,
    items_count       NUMBER,
    sales_qty         NUMBER,
    subtotal          NUMBER,
    discount          NUMBER,
    delivery_fee      NUMBER,
    gst               NUMBER,
    sales_amount      NUMBER,
    currency          STRING,
    payment_method    STRING,
    order_status      STRING,
    customer_rating   NUMBER,
    delivery_time_min NUMBER
  );

  -- generated/order_items.csv (clean, typed):
  CREATE OR REPLACE TABLE RAW.order_items (
    order_item_id NUMBER,
    order_id      NUMBER,
    r_id          NUMBER,
    f_id          STRING,
    price         NUMBER,
    quantity      NUMBER,
    line_amount   NUMBER
  );

  -- generated/reviews.csv (clean, typed) — free text for the AI layer:
  CREATE OR REPLACE TABLE RAW.reviews (
    review_id     NUMBER,
    order_id      NUMBER,
    user_id       NUMBER,
    restaurant_id NUMBER,
    rating        NUMBER,
    comment       STRING,
    review_date   DATE
  );