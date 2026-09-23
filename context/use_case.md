# Superstore Sales Analytics — Tableau-to-AtScale migration test bed

## Purpose

Re-host Tableau's shipped `Superstore.twbx` sample workbook (21 worksheets, 6 dashboards,
111 calculated fields, 32 parameters) on an AtScale semantic model instead of its original
Excel/CSV extracts. The model is a deliberate stress test: it is built to exercise the
constructs that a Tableau workbook leans on and that a semantic layer must absorb.

A second phase re-hosts the public "LOD torture pack" — Tableau's own 15 LOD-expression
workbooks and the Flerlage Twins' "20 Uses for LOD Calculations" — all of which are built
on the same Superstore data, so they run against this same model.

## Personas

- **Sales operations analyst** — tracks sales, profit, quantity and discount by product,
  customer segment, geography and time; compares actuals against category/segment targets.
- **Regional manager** — owns a region, monitors their region's sales versus target and
  their sales team's booked volume.
- **BI engineer (migration owner)** — verifies that dashboard numbers reproduce exactly
  against the semantic layer and that Tableau-side workarounds become model constructs.

## Business processes modelled

1. **Order lines** (transactional) — every line of every order: sales, profit, quantity,
   discount, whether the order was returned, and how long it took to ship.
2. **Sales targets** (planning) — a target sales figure set per product category, customer
   segment and day. Deliberately coarser than the order line: it carries no product, no
   customer and no geography.
3. **Sales-person commission** (reference volume) — booked sales per salesperson per region.
   Covers only three of the four regions; the South region has no salespeople in the source.

## Named metrics

- **Sales**, **Profit**, **Quantity** — additive order-line measures.
- **Discount** — averaged, not summed.
- **Order Count**, **Customer Count**, **Product Count** — distinct counts.
- **Line Count** — order-line row count.
- **Profit Ratio** = Profit / Sales.
- **Sales per Customer** = Sales / Customer Count.
- **Profit per Order** = Profit / Order Count.
- **Average Order Value** = Sales / Order Count.
- **Average Days to Ship** — mean of (ship date − order date).
- **Returned Sales**, **Returned Order Count**, **Return Rate** = Returned Order Count / Order Count.
- **Sales Target** — the planning measure.
- **Sales vs Target** = Sales − Sales Target; **Target Attainment** = Sales / Sales Target.
- **Commission Sales** — booked sales per salesperson.
- **First Order Date** — earliest order date, used for customer-cohort analysis.
- Time intelligence: **Sales Year to Date**, **Sales Prior Year**, **Sales YoY Growth Percent**
  on the order-date axis; **Sales Shipped Year to Date** on the ship-date axis.

## Hierarchies

- **Date** — Year > Quarter > Month > Day. Calendar. Role-played twice: order date and ship date.
- **Product** — Category > Sub-Category > Product.
- **Customer** — Segment > Customer.
- **Geography** — Region > State/Province > City > Postal Code. Region is intentionally the
  top level and is country-agnostic, because the target and commission sources key on region
  name alone. Country hangs off State as an attribute.
- **Sales Person** — flat, private to the commission process.

## Modelling constraints discovered in the source data

- `product_id` is reused across genuinely different products (32 ids, e.g. `FUR-BO-10002213`
  is both a bookcase and a library unit), so the product key must be composite.
- One customer ("Harry Olson") holds four distinct `customer_id` values, so a distinct count
  of customer ids overstates people. Both keys are exposed.
- The commission source carries a single placeholder date (`2002-01-01`) for all rows; it is
  meaningless and must NOT be related to the date dimension.
- Sales targets are not unique at (category, date, segment) — three grains repeat. They sum.

## Time window

Calendar. Orders run 2023-01-03 to 2026-12-30; ship dates extend to 2027-01-05. The date
dimension spans 2023-01-01 to 2027-12-31.

## Currency

USD.
