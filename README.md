# Superstore Sales Analytics — SML model

A Tableau-to-AtScale migration test bed. The model re-hosts Tableau's shipped
`Superstore.twbx` sample workbook (21 worksheets, 6 dashboards, 111 calculated fields,
32 parameters) on a semantic layer, and is shaped to also carry the public LOD-expression
workbooks (Tableau's own 15 + the Flerlage Twins' "20 Uses for LOD Calculations"), which
run on the same Superstore data.

Target: **BigQuery** `atscale-sales-demo.SUPERSTORE_TABLEAU_DEMO`.

## Inputs

| Input | File | Description |
|---|---|---|
| Use case | `context/use_case.md` | Personas, business processes, named metrics, hierarchies, and the modelling constraints found in the source data. |
| NLQs | `context/nlqs.md` | 20 questions — 12 from the Superstore workbook's own worksheets, 8 from the LOD pack that phase two must answer. |
| DDL | `context/ddl.sql` | `CREATE TABLE` for all 8 BigQuery tables, generated from `INFORMATION_SCHEMA.COLUMNS` of the live dataset. |
| ERD | `context/erd.mmd` | Mermaid diagram showing both role-plays and the two rollup-level joins. |
| Data profile | `context/data_profile.yaml` | Per-column `distinct` / `nulls` / `unique_key`, measured by a live scan. Drives every `is_unique_key` decision (Rule 16). |
| Build config | `context/build.yaml` | The effective build configuration assembled from the caller prompt. |
| Existing SML | (not provided) | New model, not an extension. |

## Build parameters

| Parameter | Value |
|---|---|
| `unrelated_dimension_handling` | `repeat` |
| `warehouse` | BigQuery |
| `database` | `atscale-sales-demo` |
| `schema` | `SUPERSTORE_TABLEAU_DEMO` |
| `model_unique_name` | `superstore_sales_analytics` |
| `catalog_unique_name` | `superstore_sales_analytics_catalog` |
| `currency` | USD |
| `time_window` | calendar |
| `use_cases_covered` | all |
| `use_cases_excluded` | (none) |
| `semi_additive_default` | `none` |

## Assumptions and decisions

- **warehouse = BigQuery** — stated in the caller prompt and confirmed by the lowercase unquoted identifiers in `context/ddl.sql`. Identifiers emitted lowercase per Rule 1.
- **schema = SUPERSTORE_TABLEAU_DEMO (uppercase)** — the BigQuery dataset is physically named in uppercase, matching the project's existing convention (e.g. `PELOTON_CF_COMMERCE_DEMO`). BigQuery dataset names are case-sensitive, so this is preserved verbatim while table and column names stay lowercase. Rule 17 (concrete identifiers) over Rule 1's lowercase default.
- **model_unique_name = superstore_sales_analytics** — derived from the use case title. "Superstore" is Tableau's fictional sample retailer, not a customer name, so Rule 18 does not apply.
- **unrelated_dimension_handling = repeat** — build config; applied uniformly to all 14 base metrics. Required because this is a three-fact model and most dimension/metric pairs cross a fact boundary.
- **semi_additive_default = none** — all three facts are transactional or planning, none is a snapshot balance. No `semi_additive:` block emitted, so Rule 19 does not engage.
- **currency = USD / time_window = calendar** — stated in the use case.
- **NUMERIC columns typed `decimal(38,9)`** — round-trips BigQuery's NUMERIC exactly rather than narrowing to `double`.
- **Secondary attributes use the parent-key pattern (Rule 8b Pattern A)** throughout. Several attribute columns are cyclical (`quarter_num`, `month_num`, `day_of_month`) or outright non-unique (`product_id`), so value-keying would fan out.
- **`fact_sales_commission` is NOT related to `Date Dimension`** — its source date is a single placeholder (`2002-01-01` on all 41 rows) with no meaning. Relating it would hang a dangling 2002 member off a hierarchy that otherwise spans 2023–2027.
- **Region is the top of Geography, and Country is an attribute of State** — Central, East and West each span both the United States and Canada, so `Country → Region` is not a valid parent-child. Region must also stay country-agnostic because the commission and People sources key on region name alone.
- **`Product` level keyed on `product_key` (`product_id|product_name`)** — `product_id` is reused across 32 genuinely different products (e.g. `FUR-BO-10002213` is both a bookcase and a library unit), so a single-column key would silently mis-attribute rows.
- **`City` level keyed on `city_key` (`state|city`)** — 58 city names appear in more than one state.
- **Order ID, Ship Mode and Return Status are degenerate dimensions** (`is_degenerate: true`, no `type:`, bound to `fact_order_line`, listed in the model `dimensions:` block per Rule 12). Order ID is exposed deliberately: it is the grain every `{FIXED [Order ID]: ...}` LOD in the workbooks aggregates to.
- **`is_unique_key` set only where the profile proves it** (Rule 16): `Day`/`date_key`, `Product`/`product_key`, `Customer`/`customer_id`, `Postal Code`/`geo_key`, `Sales Person`/`sales_person`. The three degenerate dims carry no flag.
- **Returns folded onto the fact, not modelled as its own dimension table** — a `COALESCE(returned,'No')` calculated column gives a clean Yes/No slicer and keeps the returned-sales metrics fact-sourced, avoiding the "metric on a dimension dataset" trap (Rule 20).
- **`Day` level surfaces `date_key` (a real DATE) as its `name_column`**, not a cast string. Tableau's connector needs a genuine date to offer native truncation, continuous axes and date-range filters; a string-typed day gives discrete text that sorts alphabetically.
- **`First Order Date Key` is a numeric `YYYYMMDD` measure, not a date.** A `minimum`-over-a-DATE metric loads in AtScale but breaks Tableau at data-source load with *"Ignoring properties for '[X]', can't interpret field as measure"* — Tableau measures must be numeric.
- **`Sales per Customer` divides by `Customer Name Count` (800), not `Customer Count` (804).** The Tableau workbook uses `countD([Customer Name])`; `customer_name` is denormalized onto the fact so the distinct count stays fact-sourced. Both counts remain exposed.
- **`Order Profitable?` is deliberately NOT materialized.** Tested live: Tableau's `{FIXED [Order ID]: SUM([Profit])}` pushes down to AtScale as a derived-table self-join and returns exactly correct numbers, so no model-side flag is needed.
- **Ship-axis MDX limited to `Sales Shipped Year to Date`** — Rule 4 ties the time axis to the verb in the metric name, and only that metric carries a "shipped" verb. All other time-intelligence uses the Order Date role-play.

## Generation summary

| Object | Count |
|---|---|
| Datasets | 8 (5 dimension, 3 fact) |
| Dimensions | 8 (5 related + 3 degenerate) |
| Base metrics | 15 |
| Calculated metrics | 11 |
| Model relationships | 10 |

- **Role-play prefixes:** `Order {0}` and `Ship {0}` on `Date Dimension`. Both `fact_order_line` and `fact_sales_target` use the Order role-play.
- **Rollup-level joins (the point of the exercise):** `fact_sales_target` attaches to `Product Dimension` at **Category** and `Customer Dimension` at **Segment** — both well above the leaf. `fact_sales_commission` attaches to `Geography Dimension` at **Region**. These are the constructs the Tableau workbook could only express with data blending.
- **Snowflake bridges:** none. Every dimension is backed by a single table, so Rules 5/9/11 do not engage.
- **Calculated columns added:** `days_to_ship`, `returned_sales`, `returned_order_id` on `fact_order_line`; `date_name` on `dim_date`. Materialized on the fact in BigQuery: `customer_name`, `order_date_key`.
- **Parallel-period columns:** `prior_year_quarter_key`, `prior_year_month_key`, `prior_year_date_key` materialized on `dim_date`, wired to Quarter/Month/Day levels per Rule 13. `prior_year_num` is present for reference.
- **MDX functions used:** `CASE`, `ISEMPTY`, `Aggregate`, `PeriodsToDate`, `ParallelPeriod`, `CurrentMember` — all present in `references/mdx-reference/INDEX.md`.

### Known caveats

- `fact_sales_target` is not unique at `(category, order_date, segment)` — three grains repeat on 2024-03-01. They sum, which is faithful to the source.
- `fact_sales_commission` has no South region, so `Commission Sales` is empty for South. This is a property of the source and is the intended unmatched-join test.
- Two customer counts are exposed on purpose: `Customer Count` = 804 distinct **ids**, `Customer Name Count` = 800 distinct **names** (Harry Olson holds four ids). `Sales per Customer` uses the name count to match the workbook. Picking the wrong one shifts the ratio by ~0.5%.
- A Tableau FIXED LOD must be expressed as a **join**, not a semi-join: AtScale rejects `col IN (SELECT ...)`. It also requires the outer measure to be explicitly wrapped (`SUM(t0."Sales")`) inside a self-join, which is the opposite of the bare-measure convention for plain queries. Tableau's own generated SQL uses the working shape.
- Phase two (the LOD pack) will need two additional query datasets — order-grain and customer-grain pre-aggregates — for the nested LODs (`AVG` of a per-order `SUM`, customer-cohort `MIN([Order Date])` feeding a bin). They are intentionally not emitted yet.

## Reproducing this build

`context/` holds verbatim copies of every input this build consumed, including `build.yaml`.
Re-running the generator with the same inputs and build parameters produces an equivalent
model. The BigQuery tables the model reads are themselves reproducible from the three files
inside Tableau's shipped `Superstore.twbx`.
