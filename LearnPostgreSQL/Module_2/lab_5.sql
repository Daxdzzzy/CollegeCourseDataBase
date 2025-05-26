-- In this module, we'll explore how PostgreSQL handles view execution at runtime, identify potential performance bottlenecks, andd see when and how to use materialized views to cache results. 

-- View inlining 

-- When you execute a query against a regular view (e. g., SELECT * FROM v;), PostgreSQL doesn't fetch any precomputed data. Instead, it treats the view as a macro: the planner retrieves the view's stored parse tree (from pg_rewrite), subtitutes that definitions into your query, and forms a single combined query against the base tables.

CREATE VIEW v_recent_orders AS
  SELECT o.order_id, o.customer_id, o.order_total
    FROM orders o
  WHERE o.placed_at > NOW() - INTERVAL '7 days';

SELECT customer_id, SUM(order_total) AS week_spend
  FROM v_recent_orders
WHERE order_total > 50

--Internally, PostgreSQL transforms this into:
SELECT customer_id, SUM(order_total) AS week_spend
  FROM (
    SELECT o.order_id, o.customer_id, o.order_total
      FROM orders o
     WHERE o.placed_at > NOW() - INTERVAL '7 days'
  ) AS sub
 WHERE order_total > 50
GROUP BY customer_id;

-- OR

SELECT o.customer_id, SUM(o.order_total) AS week_spend
  FROM orders o
 WHERE o.placed_at > NOW() - INTERVAL '7 days'
   AND o.order_total > 50
GROUP BY o.customer_id;

-- Optimizer behavior: PostgreSQL planner "pushes down" filters (order_total > 50) into the inner query when possible. It combines predicates and chooses indexes as though you had written a single query yourself.


-- Even though regular views introduce no storage overhead, they can still be expensive when: 

-- Underlying query is complex: Large numbers of joins, window functions, or aggreagates over huge tables fotce the planner to scan, aggreagate, and sort big datasets on every query.

-- Example: A view combining three large tables with multiple joins and a GROUP BY will re-execute that entire join/aggregation each time you query it.

-- Frequent Re-Execution: If you have a dashboard or report that hits a view dozens (or hundreds) of times per minute, each invocation causes the entire underlying query to run

-- Nested or chained views: Stacking views on top of views can lead yo deeply nested inlining at plan time. While PostgreSQL flattens most nested views, complex layers can obscure the final plan and cause suboptimal index choices.

-- Lack of appropriate indexes: If filters in the view or in the outer query aren't supported by b-tree or other indexes, PosgreSQL must resort to massive sequential scans. 

-- Volatile expressions: Views that reference NOW(), CURRENT_DATE, or other volatile functions force re-evaluation on every query, potentially invalidating cached plans or preventing index usage adjustments. 


-- IDENTIFYING EXPENSIVE VIEWS

-- Before choosing to convert a view into a materialized view, you should
SELECT customer_id, SUM(order_total) AS week_spend
  FROM v_recent_orders
 WHERE order_total > 50

-- GROUP BY customer_id; 

-- Look for high-cost steps:  
-- Large sequential scans  
-- Expensive hash joins or sorts  
-- Repeated execution for each dashboard panel, etc.

-- Check View Definition Complexity
SELECT definition
  FROM pg_views
 WHERE viewname = 'v_recent_orders';
-- If the definition contains multiple joins, subqueries, or a wide GROUP BY, it’s a candidate for materialization.

-- Estimate data freshness requirements: How stale can the data get before it's uncacceptable? If you only need the last week's aggregated totals updated once per hour, continuous re-execution on each query is overkill.

-- Monitor real-time usage patterns

-- Track how often and by how many users the view is queried. If a nightly analystics job runs the same view 50 times, caching result can save a lot of I/O.


-- 1. Materialized vies: Caching results

-- A materialized view stores the result of its underlying query on disk. Unlike a refular view, it does not re-execute on every query. Instead, you explicitly refresh it to incorporate new data.

-- Creating a materialized view.

CREATE MATERIALIZED VIEW mv_weekly_sales AS
  SELECT customer_id,
         DATE_TRUNC('day', placed_at) AS sale_day,
         SUM(order_total) AS daily_total
    FROM orders
   WHERE placed_at > NOW() - INTERVAL '7 days'
GROUP BY customer_id, DATE_TRUNC('day', placed_at)
WITH NO DATA;  -- Optional: creates definition but no data initially

-- WITH NO DATA defers the first population to a later REFRESH MATERIALIZED VIEW. Omitting it populates immediately.

-- PostgreSQL writes the results rows into a new physical table under the hood (in pg_class) and marks it as a materialized view.

-- Populating and refreshing.

-- Initial population (if created with WITH NO DATA):
REFRESH MATERIALIZED VIEW mv_weekly_sales;

-- Regular refresh strategies:

-- On-demand (Manual):
REFRESH MATERIALIZED VIEW mv_weekly_sales;
--Use this when you control exactly when data must be updated (e.g., a nightly cron job at 2:00 AM).

-- Concurrent refresh:
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_weekly_sales;
-- Keeps the old data available for selects while building a new copy in a temporary table. Only works if the materialized view has a unique index on one or more columns.

-- Example

CREATE UNIQUE INDEX idx_mv_weekly_sales ON mv_weekly_sales (customer_id, sale_day);

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_weekly_sales;
-- Trade-Off: Concurrent refresh takes longer (it writes to a temporary table and then swaps). But it avoids blocking reads.

-- Scheduling refreshes via cron or pg_cron:
-- Example using pg_cron extension:
SELECT cron.schedule(
  'refresh_mvw',
  '0 * * * *',       -- every hour at minute 0
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY mv_weekly_sales$$
);
-- Ensures houtly updates without downtime for read queries.

-- Indexing a materialzed view

-- Since the materialized view is a physiscal table, you can (and should) create indexes to accelerate queries: 

CREATE INDEX idx_mv_weekly_sales_cust_day ON mv_weekly_sales (customer_id, sale_day);
CREATE INDEX idx_mv_weekly_sales_daily_total ON mv_weekly_sales (daily_total);

-- Planning with indexes: Once the materialized view is populated, queries like.
SELECT sale_day, SUM(daily_total) AS total_sales
  FROM mv_weekly_sales
 WHERE customer_id = 12345

-- GROUP BY sale_day can use `idx_mv_weekly_sales_cust_day` to skip scanning unrelated rows, making the query very fast.

-- 2. Building a Materialized reporting pipeline

-- You have a large sales table with millions of rows. You need a daily summary of total sales per region. Running:

SELECT region, SUM(amount) AS total_sales
  FROM sales
GROUP BY region;

-- Takkes several seconds or more, and you don't need real-time data once a day freshness is sufficient.

-- Create a materialized view.

CREATE MATERIALIZED VIEW mv_daily_region_sales AS
  SELECT region,
         SUM(amount) AS total_sales,
         DATE_TRUNC('day', sold_at) AS sale_date
    FROM sales
   WHERE sold_at >= NOW() - INTERVAL '1 day'
GROUP BY region, DATE_TRUNC('day', sold_at)
  WITH NO DATA;

-- Create a unique index.
-- This is required if you wnat yo use CONCURRENTLY.

CREATE UNIQUE INDEX idx_mv_daily_region_sale_date_region
  ON mv_daily_region_sales (sale_date, region);

-- Initial population
REFRESH MATERIALIZED VIEW mv_daily_region_sales;

-- Set up scheduled refresh (nightly at 2 AM) 
SELECT cron.schedule(
  'refresh_daily_sales',
  '0 2 * * *',  -- every day at 02:00
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_region_sales$$
);

-- Querying the materialized view

SELECT region, total_sales
  FROM mv_daily_region_sales
 WHERE sale_date = CURRENT_DATE - INTERVAL '1 day';

-- This query hits the indexed table directly, returning results in milliseconds.

-- Monitoring refresh performance:

-- Periodically check how long the REFRESH CONCURRENTLY takes. If it starts exceeding your maintenance window, consider: 

-- Breaking up the materialized view (e.g., separate per region),

-- Refreshing fewer partitions (e.g., only yesterday’s data), or

-- Using incremental maintenance approaches (covered below).

-- 3. Incremantal / Partial refresh strategies.

-- PostgreSQL’s built-in REFRESH MATERIALIZED VIEW always recomputes the entire result set. For very large datasets, this can be expensive. Two common patterns can help:

-- Partitioned Materialized Views

-- Partition the underlying data by date (e.g., sales table partitioned by month or day).

-- Create a materialized view for each partition (for example, mv_sales_2025_05_23 for May 23, 2025).

--  Refresh only the views for partitions with new data.

-- Or, use a union-all view over all partitioned materialized views for querying.

-- Suppose sales is range-partitioned by sold_at:
CREATE TABLE sales_2025_05_23 PARTITION OF sales FOR VALUES FROM ('2025-05-23') TO ('2025-05-24');

CREATE MATERIALIZED VIEW mv_sales_2025_05_23 AS
  SELECT region, SUM(amount) AS total_sales
    FROM sales_2025_05_23
GROUP BY region WITH NO DATA;

-- Index for concurrent refresh:
CREATE UNIQUE INDEX idx_mv_sales_2025_05_23_region ON mv_sales_2025_05_23 (region);

-- Refresh for that day only:
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_sales_2025_05_23;

-- Pros:

-- Each partition’s materialized view is smaller and faster to refresh.

-- You only touch new partitions, leaving historical data unchanged.

-- Cons:

-- More objects to manage (one matview per partition).

-- Union-all querying logic can get complex.

-- Incremental Updates via Triggers/Custom Tables

-- Maintain a helper table that tracks which base-table rows have changed since the last refresh (e.g., an “audit” or “delta” table).

-- Write triggers on the base table that insert changed primary keys into this delta table.

-- On refresh, delete old rows from the matview corresponding to those primary keys, recompute only the affected keys’ aggregates, and insert updated values.

-- Base table trigger:

CREATE TABLE sales_delta (
  sale_id   BIGINT PRIMARY KEY,
  changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE FUNCTION track_sales_changes() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO sales_delta (sale_id) VALUES (NEW.sale_id)
    ON CONFLICT (sale_id) DO UPDATE SET changed_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Partial refresh function

CREATE OR REPLACE FUNCTION refresh_mv_sales_delta() RETURNS VOID AS $$
BEGIN
  -- Delete outdated matview rows
  DELETE FROM mv_daily_region_sales
   WHERE sale_date IN (
     SELECT DATE_TRUNC('day', s.sold_at)
       FROM sales s
       JOIN sales_delta d ON d.sale_id = s.sale_id
   ) AND region IN (
     SELECT s.region
       FROM sales s
       JOIN sales_delta d ON d.sale_id = s.sale_id
   );

  -- Recompute aggregates only for affected dates/regions
  INSERT INTO mv_daily_region_sales (region, total_sales, sale_date)
  SELECT region, SUM(amount), DATE_TRUNC('day', sold_at)
    FROM sales
   WHERE DATE_TRUNC('day', sold_at) IN (
     SELECT DATE_TRUNC('day', s.sold_at)
       FROM sales s
       JOIN sales_delta d ON d.sale_id = s.sale_id
   )
GROUP BY region, DATE_TRUNC('day', sold_at)
  ON CONFLICT (sale_date, region) DO UPDATE
    SET total_sales = EXCLUDED.total_sales;

  -- Clear the delta tracking table
  TRUNCATE TABLE sales_delta;
END;
$$ LANGUAGE plpgsql;



CREATE TRIGGER trg_sales_changes
  AFTER INSERT OR UPDATE OR DELETE ON sales
  FOR EACH ROW EXECUTE FUNCTION track_sales_changes();

-- Schedule partial refresh

SELECT cron.schedule(
  'partial_refresh_sales',
  '*/5 * * * *',  -- every 5 minutes
  $$SELECT refresh_mv_sales_delta();$$
);

-- Pros:

-- Extremely fast incremental updates.

-- Matview stays nearly up-to-date with minimal work.

-- Cons:

-- More complex to implement and maintain.

-- Potential for bugs if triggers or delta tables get out of sync.

-- 4. Concurrency and locking considerations.

-- Regular Views, No Extra Locks:

-- Since regular views are just SQL macros, querying them locks only the base tables according to the usual lock modes (e.g., AccessShareLock for reads). There’s no special view-level lock.

-- Materialized views: 

-- Non-Concurrent refresh (Default):

REFRESH MATERIALIZED VIEW mv_name;

-- Exclusive Lock: Blocks all reads (ACCESS EXCLUSIVE LOCK) on mv_name until refresh is complete.

-- Impact: Any SELECT against the matview will wait until the refresh finishes. For large datasets, this can cause application timeouts or UI errors.

-- Concurrent refresh

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_name;

-- Requires a unique index on the materialized view.

-- Acquires a share update exclusive lock on mv_name to prevent schema changes.

-- Builds a new copy of the data in a temporary table.

-- Swaps in the new data with an atomic rename—reads continue to see the old data while building.

-- Once the swap is done, readers immediately see the new data.

-- Pros: Minimal downtime; reads are almost never blocked.

-- Cons: Takes more time and space (duplicates the data briefly) and can fail if conflicting schema changes occur while refreshing.

-- Recommendations

-- Use Regular Views for Lightweight Abstraction

-- When your view’s underlying query is relatively simple (a few joins, not millions of rows), a regular view is sufficient. There’s no maintenance overhead.

-- Convert to Materialized View for Expensive Aggregations

-- If your view’s query takes more than a couple of hundred milliseconds and users run it frequently (e.g., dashboards, BI reports), consider materializing it.

-- Target views that summarize or aggregate large tables (e.g., daily sales totals, monthly user signups).

-- Schedule Refreshes During Off-Peak Hours

-- If you can afford some staleness (e.g., daily reports), schedule REFRESH when load is low (overnight). Use CONCURRENTLY if reads must remain available.

-- Always Index Materialized Views

-- After creating the matview, identify the most common query patterns and create appropriate indexes (e.g., on grouping keys, filter predicates).

-- Without indexes, queries against a matview can be nearly as slow as against the base tables.

-- Monitor Refresh Times and Resource Usage

-- Track how long each REFRESH takes (e.g., via pg_stat_activity or logs). If it creeps above acceptable thresholds, investigate incremental/partition strategies.

-- Avoid Unnecessary Nesting of Views

-- Deep chaining of views can lead to suboptimal query plans. If you materialize an intermediate result, it may simplify downstream queries and the optimizer’s job.

-- Understand Freshness Requirements

-- If users expect “live” data, materialized views may not be appropriate without very frequent refresh (which can become expensive).

-- For dashboards where “updated within the last hour” is OK, hourly or even half-hourly refresh is often a good balance.

-- Consider Hybrid Approaches

-- Use a combination of regular and materialized views:

-- Keep base-level “up-to-date” summary materialized views (e.g., last 24 hours of data), and have regular views on top to apply additional filters or combines.

-- This can limit the amount you need to refresh regularly while still providing flexibility.


