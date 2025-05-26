-- Advances topics (recursive views and view chaining)

-- What's recursive view?

-- A recursive view isn’t a separate “view type” in PostgreSQL. Instead, you define a view whose query uses a recursive Common Table Expression (CTE) (WITH RECURSIVE). This allows you to define hierarchical or graph-structured queries (e.g., organizational hierarchies, bill-of-materials explosions) once and then reference them as a view.

-- Internally, PostgreSQL treats the WITH RECURSIVE query as a single parse tree.

-- When you create a view on top of that CTE, the view stores the full recursive query.

-- At runtime, querying the view executes the recursive CTE until it reaches a fixed point (no new rows).

-- Suppose you have an employees table with a self-referencing foreign key indicating each employee’s manager:

CREATE TABLE employees (
  employee_id   SERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  manager_id    INT REFERENCES employees(employee_id),
  department    TEXT NOT NULL
);

INSERT INTO employees (name, manager_id, department) VALUES
  ('David',    NULL,      'Executive'),
  ('Bob',      1,         'Engineering'),
  ('Diego',    1,         'Sales'),
  ('Elkin',    2,         'Engineering'),
  ('Eve',      2,         'Engineering'),
  ('Erickson', 3,         'Sales'),
  ('Grace',    3,         'Sales');

-- Define a recursive CTE

WITH RECURSIVE reporting_chain AS (
  -- Anchor member: start with top-level managers
  SELECT
    employee_id,
    name,
    manager_id,
    name AS top_manager,
    0 AS level
  FROM employees
  WHERE manager_id IS NULL

  UNION ALL

  -- Recursive member: find direct reports and carry forward top_manager
  SELECT
    e.employee_id,
    e.name,
    e.manager_id,
    rc.top_manager,
    rc.level + 1 AS level
  FROM employees e
  JOIN reporting_chain rc
    ON e.manager_id = rc.employee_id
)
SELECT *
  FROM reporting_chain;

-- Anchor Query (level = 0): selects all employees without a manager (David).

-- Recursive Step: repeatedly joins employees to the rows in reporting_chain, building the chain and increasing level until no more matches.

-- PostgreSQL nodes for CTE evaluation (in the planner) detect that it’s recursive and use a “working table” algorithm—iteratively inserting new rows into a temporary structure until saturation.

-- Create a view from the Recursive CTE

CREATE VIEW employee_reporting_chain AS
WITH RECURSIVE reporting_chain AS (
  SELECT
    employee_id,
    name,
    manager_id,
    name AS top_manager,
    0 AS level
  FROM employees
  WHERE manager_id IS NULL

  UNION ALL

  SELECT
    e.employee_id,
    e.name,
    e.manager_id,
    rc.top_manager,
    rc.level + 1
  FROM employees e
  JOIN reporting_chain rc
    ON e.manager_id = rc.employee_id
)
SELECT *
  FROM reporting_chain;

-- Query the recursive view

SELECT employee_id, name, top_manager, level
  FROM employee_reporting_chain
 ORDER BY top_manager, level, name;

-- PostgreSQL’s planner recognizes the recursive CTE in the view definition.

-- On each query, it builds a temporary working table, executes the anchor member, then repeatedly executes the recursive member for newly produced rows.

-- The view does not precompute or cache results—it recomputes the entire CTE each time you query it.

-- If the organizational chart is relatively small (a few thousand rows), the recursive view usually performs adequately, especially with an index on manager_id.

-- Ensure an index exists on employees(manager_id) to efficiently find direct reports.

-- Deep or Large-Scale Graphs:

-- For tens or hundreds of thousands of rows with many levels, the recursive CTE can become slow because each iteration may perform large joins.

-- Mitigation Strategies:

-- Limit Depth: Add a WHERE level < X condition in the view definition if you only care about, say, three levels of reporting.

-- Materialize in Stages: Consider creating a materialized view that stores the computed chain periodically (for large organizations) and refresh it nightly.

-- Use an Adjacency List Table with Caching: Maintain a denormalized “path” column (e.g., ltree extension) to accelerate lookups. If you use ltree, you can index the path and query ancestry without recursion.


-- Infinite Recursion / Cycles:

-- If your data contains a cycle (e.g., A → B → C → A), the recursive CTE will loop indefinitely. PostgreSQL stops when the working set stops growing, but with a cycle, it may generate duplicates unless you add a cycle detection mechanism (e.g., track visited nodes).

-- Best Practice: Enforce data integrity so that manager_id cannot point to a descendant. You can add a trigger or constraint to prevent cycles.

-- Excessive Resource Consumption:

-- Complex recursive views can use large amounts of memory and CPU. Monitor with EXPLAIN (ANALYZE) and consider alternative designs if the run time is unacceptable.

-- Non-Intuitive Plans:

-- Recursive CTEs are optimization fences in older PostgreSQL versions (prior to 12). That means the planner cannot push down filters inside the recursive query, potentially causing full scans. Newer versions remove this “fence” for many cases, but reviewing the plan is still crucial.

-- View chaining

-- View chaining occurs when you define one view on top of another view (and possibly more layers). Each time you reference the top-level view, PostgreSQL inlines all underlying definitions recursively until it forms a single combined query against base tables.

-- Example Chain:

CREATE VIEW active_users AS
  SELECT user_id, username
    FROM users
   WHERE active = true;

CREATE VIEW active_sales_users AS
  SELECT au.user_id, au.username, s.sales_total
    FROM active_users au
    JOIN sales s ON s.user_id = au.user_id;

CREATE VIEW top_active_sales_users AS
  SELECT user_id, username, sales_total
    FROM active_sales_users
   WHERE sales_total > 1000;

-- When you run SELECT * FROM top_active_sales_users;, PostgreSQL inlines active_sales_users, which in turn inlines active_users, resulting in a query:

SELECT au.user_id, au.username, s.sales_total
  FROM (
        SELECT user_id, username
          FROM users
         WHERE active = true
       ) AS au
  JOIN sales s ON s.user_id = au.user_id
 WHERE s.sales_total > 1000;

-- And then it flattens the subquery so that the final plan is:

SELECT u.user_id, u.username, s.sales_total
  FROM users u
  JOIN sales s ON s.user_id = u.user_id
 WHERE u.active = true
   AND s.sales_total > 1000;

-- Plan Simplification by the Optimizer:

-- When the planner flattens nested view definitions, it can push filters (u.active = true, s.sales_total > 1000) down to the base tables, allowing efficient index usage.

-- PostgreSQL merges all predicates and join conditions into a single query tree before generating the execution plan.

-- Potential for “Query Explosion”:

-- Deeply nested views with many layers can generate a very large combined query, making it harder to read or debug.

-- The optimizer must traverse multiple catalogs (pg_views, pg_rewrite) to fetch each view’s definition, then inline recursively.

-- Performance Impact:

-- In most cases, view chaining does not inherently slow down queries, since the end plan is the same as if you’d written the combined query yourself.

-- However, if any view in the chain is a materialized view, the optimizer treats it as a base table, and the chained view will query that stored data rather than inlining.

-- Maintenance Complexity:

-- Changing an intermediate view (e.g., renaming a column or adding a filter) can break all downstream views.

-- PostgreSQL tracks dependencies in pg_depend, so attempting to ALTER or DROP without CASCADE will fail if there are dependents.

-- Consider a reporting requirement that evolves over time:

CREATE TABLE orders (
  order_id     SERIAL PRIMARY KEY,
  user_id      INT NOT NULL,
  amount       NUMERIC(12,2) NOT NULL,
  region       TEXT NOT NULL,
  placed_at    TIMESTAMP NOT NULL,
  status       TEXT NOT NULL  -- e.g., 'completed', 'pending', 'canceled'
);

-- View: Filter completed orders.
CREATE VIEW completed_orders AS
  SELECT order_id, user_id, amount, region, placed_at
    FROM orders
   WHERE status = 'completed';

-- View Add Salesperson Data: Suppose you have a salespeople table mapping user_id to sales_region:
CREATE TABLE salespeople (
  user_id      INT PRIMARY KEY,
  sales_region TEXT NOT NULL
);

-- You want a view that adds sales_region:

CREATE VIEW completed_orders_with_region AS
  SELECT co.order_id,
         co.user_id,
         co.amount,
         co.region       AS order_region,
         sp.sales_region AS salesperson_region,
         co.placed_at
    FROM completed_orders co
    JOIN salespeople sp ON sp.user_id = co.user_id;

-- View, High-Value Regional Orders Now create a view atop completed_orders_with_region to show only orders over $1,000 grouped by sales region:

CREATE VIEW high_value_regional_sales AS
  SELECT salesperson_region,
         SUM(amount) AS total_sales
    FROM completed_orders_with_region
   WHERE amount > 1000
GROUP BY salesperson_region;

SELECT *
  FROM high_value_regional_sales;

-- Internally, PostgreSQL inlines all three view definitions to produce:

SELECT sp.sales_region AS salesperson_region,
       SUM(co.amount) AS total_sales
  FROM (
    SELECT order_id, user_id, amount, region, placed_at
      FROM orders
     WHERE status = 'completed'
  ) AS co
  JOIN salespeople sp ON sp.user_id = co.user_id
 WHERE co.amount > 1000

-- GROUP BY sp.sales_region;
SELECT sp.sales_region AS salesperson_region,
       SUM(o.amount) AS total_sales
  FROM orders o
  JOIN salespeople sp ON sp.user_id = o.user_id
 WHERE o.status = 'completed'
   AND o.amount > 1000
GROUP BY sp.sales_region;

-- Modularity: Each intermediate view encapsulates a logical step—filtering, joining, aggregating—making it easier to reason about and test.

-- Reusability: You can use completed_orders in multiple places (e.g., other reports) without rewriting the status = 'completed' filter each time.

-- Maintainability: Changing the base logic (e.g., redefining “completed” to include “shipped”) in one view automatically propagates to all downstream views.

-- Debugging Complexity: When performance is suboptimal, tracing a slow query back through multiple layers of views can be time-consuming.

-- Dependency Fragility: Renaming or dropping a column in a base or intermediate view often requires updating all dependent views. Managing versioned deployments can become tricky.

-- Plan Visibility: Some tools’ EXPLAIN output may not clearly show the combined plan for a deeply chained view, making it harder to identify missing indexes or suboptimal join orders.

-- 3. Cyclic Dependencies & Prevention

-- A cyclic dependency occurs when two or more views (or tables and views) depend on each other in a cycle. For example:

-- View A references View B
CREATE VIEW view_a AS
  SELECT * FROM view_b WHERE some_column = 1;

-- View B references View A
CREATE VIEW view_b AS
  SELECT * FROM view_a WHERE other_column = 2;

-- PostrgreSQL will reject this with an error like: 
ERROR:  cycle detected in rewrite rules

-- because it cannot resolve how to inline one view into the other without infinite recursion.

-- Design Views with a Single Direction of Dependency:

-- Ensure that view definitions “flow” from base tables outward—never have a downstream view refer back to an upstream view.

-- Split Complex Logic into Functions Instead of Views:

-- If two pieces of logic mutually depend on each other, consider using stored procedures or functions rather than views.

-- Use Materialized Views If Necessary:

-- Materialized views break the cycle because they become static tables at query time. You could define view_a as a materialized view, then have view_b reference that. However, this sacrifices “always live” data.

-- Limit Depth of Chaining

-- Avoid more than two or three layers of views for mission-critical queries. Beyond that, performance tuning and debugging become difficult.

-- Use EXPLAIN (VERBOSE) to Inspect Plans

-- When you query a chained or recursive view, run:
EXPLAIN (ANALYZE, VERBOSE) SELECT * FROM top_view;

-- and inspect the output to confirm that predicates and joins have been pushed down as intended.

-- Document Dependencies

-- Maintain a simple mapping of “View X depends on tables A, B, and views Y, Z.” This helps when schema changes are needed.

-- Index Underlying Tables Appropriately

-- Since chained views get flattened, indexing should target the base tables’ columns used in joins and filters. Indexes on intermediate views are irrelevant for performance (they don’t store data).

-- Consider Materializing Sub-Queries When Needed

-- If part of a chained view is especially expensive but doesn’t change often (e.g., a monthly summary), convert that layer into a materialized view. Downstream views will then read from the stored data.

-- Be Cautious with Large Recursive CTEs

-- For very large hierarchies, investigate ltree or other graph-traversal extensions instead of pure recursive CTEs. Alternatively, precompute common ancestor/descendant relationships in a side table.

-- Test Edge Cases

-- For recursive views, test what happens when the base data changes—especially when nodes are deleted or relationships are updated. Ensure that the CTE still computes the correct set and doesn’t retain stale chains.



