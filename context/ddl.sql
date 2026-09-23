-- Superstore Tableau migration — BigQuery DDL
-- project: atscale-sales-demo   dataset: SUPERSTORE_TABLEAU_DEMO

CREATE TABLE `atscale-sales-demo.SUPERSTORE_TABLEAU_DEMO.dim_customer` (
  customer_id STRING,
  customer_name STRING,
  segment STRING
);

CREATE TABLE `atscale-sales-demo.SUPERSTORE_TABLEAU_DEMO.dim_date` (
  date_key DATE,
  year_key INT64,
  quarter_key STRING,
  month_key STRING,
  quarter_num INT64,
  month_num INT64,
  day_of_month INT64,
  month_name STRING,
  month_label STRING,
  day_name STRING,
  day_of_week INT64,
  week_of_year INT64,
  day_of_year INT64,
  is_weekend BOOL,
  prior_year_num INT64,
  prior_year_quarter_key STRING,
  prior_year_month_key STRING,
  prior_year_date_key DATE
);

CREATE TABLE `atscale-sales-demo.SUPERSTORE_TABLEAU_DEMO.dim_geography` (
  geo_key STRING,
  city_key STRING,
  state_key STRING,
  region STRING,
  state_province STRING,
  city STRING,
  postal_code STRING,
  country_region STRING,
  regional_manager STRING
);

CREATE TABLE `atscale-sales-demo.SUPERSTORE_TABLEAU_DEMO.dim_product` (
  product_key STRING,
  product_id STRING,
  product_name STRING,
  sub_category STRING,
  category STRING
);

CREATE TABLE `atscale-sales-demo.SUPERSTORE_TABLEAU_DEMO.dim_sales_person` (
  sales_person STRING,
  region STRING
);

CREATE TABLE `atscale-sales-demo.SUPERSTORE_TABLEAU_DEMO.fact_order_line` (
  row_id INT64,
  order_id STRING,
  order_date DATE,
  ship_date DATE,
  ship_mode STRING,
  customer_id STRING,
  geo_key STRING,
  product_key STRING,
  is_returned STRING,
  sales NUMERIC,
  quantity INT64,
  discount NUMERIC,
  profit NUMERIC,
  category_cluster STRING
);

CREATE TABLE `atscale-sales-demo.SUPERSTORE_TABLEAU_DEMO.fact_sales_commission` (
  region STRING,
  sales_person STRING,
  commission_sales INT64
);

CREATE TABLE `atscale-sales-demo.SUPERSTORE_TABLEAU_DEMO.fact_sales_target` (
  category STRING,
  order_date DATE,
  segment STRING,
  sales_target INT64
);
