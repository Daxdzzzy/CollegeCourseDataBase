-- Security and access control using views

-- 1. Granting privileges on Views

-- In PostgreSQL, every table or view has an Acces Control List (ACL) stored in pg_class.relacl

-- You can grant or revoke specific privileges on a view independently of its underlying tables. Users without any rights on the base tables can still query (or modify, if updatable) a view, provided they have the appropriate rights on that view.

-- Granting Read-Only access

CREATE VIEW employee_public AS
  SELECT employee_id, first_name, last_name, department
    FROM employees
   WHERE active = true;

-- Allow the analyst role to read from this view only
GRANT SELECT ON employee_public TO analyst;

-- The analyst role can run SELECT * FROM employee_public;

-- Even though analyst has no direct privileges on employees, they can read from employee_public.

-- PostgreSQL stores an entry in pg_class.relacl for employee_public that grants SELECT to analyst.

-- When analyst runs the query, the planner resolves employee_public and inlines the underlying SELECT ... FROM employees WHERE active = true. However, PostgreSQL enforces that analyst has privileges on the view; it does not check privileges on employees because of the security qualifier.

-- Granting DML on an Updatable view:

CREATE VIEW in_stock_inventory AS
  SELECT item_id, name, quantity, location
    FROM inventory
   WHERE in_stock = true
  WITH CHECK OPTION;

-- Grant the store_mgr role rights to modify inventory through this view:

GRANT SELECT, INSERT, UPDATE, DELETE ON in_stock_inventory TO store_mgr;

-- store_mgr can insert new rows (which implicitly sets in_stock = true), update quantity or location, and delete rows—all via in_stock_inventory.

-- They cannot modify rows where in_stock = false, because the view’s WHERE in_stock = true plus WITH CHECK OPTION enforces that.


-- In pg_class.relacl for in_stock_inventory, you’ll find an ACL entry like {store_mgr=arwd*/owner} indicating SELECT (r), INSERT (a), UPDATE (w), DELETE (d), TRUNCATE (t) privileges granted to store_mgr.

-- Behind the scenes, PostgreSQL uses rewrite rules (in pg_rewrite) to map INSERT/UPDATE/DELETE on the view into operations on inventory. Since the view is marked updatable, those rules exist automatically. PostgreSQL checks that store_mgr has the right on in_stock_inventory and does not require separate rights on inventory.

-- Revoking privileges

REVOKE ALL ON employee_public FROM PUBLIC;

-- Before this command, everyone (PUBLIC) could read from employee_public. After revocation, only roles with explicit grants can access it.

-- Removes the ACL entry for PUBLIC from pg_class.relacl. Users without any remaining ACL entries will be prevented from querying the view.

-- Schema and Search Path Considerations

-- Qualifying View Names: If a user’s search_path includes the schema containing the view, they can refer to it unqualified. Otherwise, they must qualify with schema_name.view_name.

-- Security Implication: If you define a view in the same schema as its base tables and grant SELECT on the view but drop privileges on the base tables, be sure that malicious users cannot bypass the view by qualifying the base table name explicitly.

-- Best Practice: Place your protected tables in a separate schema (private), and only create views in a public or reports schema. Revoke USAGE on the private schema from untrusted roles so they cannot refer to the base tables.

-- Secure setup:
CREATE SCHEMA private;
CREATE TABLE private.employees (...);

CREATE SCHEMA reports;
CREATE VIEW reports.employee_public AS
  SELECT employee_id, first_name, last_name, department
    FROM private.employees
   WHERE active = true;

REVOKE USAGE ON SCHEMA private FROM PUBLIC;
GRANT USAGE ON SCHEMA reports TO analyst;
GRANT SELECT ON reports.employee_public TO analyst;

-- analyst can query reports.employee_public because they have USAGE on reports and SELECT on the view.

-- They cannot list or query anything in private, since they lack USAGE on private.

-- 2. Hiding sensitive columns and rows via views.

-- xposing Only Specific Columns Example: You have a users table containing personally identifiable information (PII):

CREATE TABLE users (
  user_id    SERIAL PRIMARY KEY,
  username   TEXT UNIQUE NOT NULL,
  email      TEXT NOT NULL,
  password   TEXT NOT NULL,  -- hashed password
  date_of_birth DATE,
  role       TEXT
);

-- CREATE A VIEW hiding PII
CREATE VIEW user_safe_profile AS
  SELECT user_id, username, role
    FROM users
   WHERE role IN ('employee', 'manager');

-- Grant view access
GRANT SELECT ON user_safe_profile TO analytics_team;

-- Members of analytics_team can query user_safe_profile and see only user_id, username, and role.

-- They cannot see email, password, or date_of_birth, nor can they access the users table directly (assuming you’ve revoked or never granted those privileges).

-- Filtering rows for role-based access

CREATE TABLE orders (
  order_id     SERIAL PRIMARY KEY,
  customer_id  INT NOT NULL,
  amount       NUMERIC(10,2) NOT NULL,
  internal_note TEXT,
  region       TEXT NOT NULL
);

-- Create separate vies per region

CREATE VIEW orders_north AS
  SELECT order_id, customer_id, amount
    FROM orders
   WHERE region = 'north';

CREATE VIEW orders_south AS
  SELECT order_id, customer_id, amount
    FROM orders
   WHERE region = 'south';

-- Grant region specific access

GRANT SELECT ON orders_north TO north_sales_team;
GRANT SELECT ON orders_south TO south_sales_team;

--north_sales_team can query only orders_north, and thus only sees orders where region = 'north'. They cannot see any rows for south.

-- They also cannot see internal_note, because it’s omitted from the view’s SELECT list.

-- View Definitions and Security Qualifiers

-- PostgreSQL treats views as security barriers by default if you create them with SECURITY INVOKER (the default). When an unprivileged user queries a view, PostgreSQL checks privileges on the view first, then executes the view’s query as the view owner. The base-table privileges of the querying user do not matter.

-- You can explicitly mark a view as a security-barrier view—this instructs the planner to prevent predicate pushdown for user-supplied filters (covered more in the “Row-Level Security” section).

CREATE VIEW sensitive_data WITH (security_barrier) AS
  SELECT ... FROM ...
 WHERE ...;

-- If you define a barrier view that filters rows, and a user runs a query with additional filters, PostgreSQL ensures the user’s filters are applied after the view-level security filter. This prevents certain side-channel attacks.

-- 3. How PostgreSQL enforces privileges internally.

-- View-Level Check

-- When a user runs SELECT * FROM some_view, PostgreSQL’s planner:

-- Looks up some_view in the catalog.

-- Verifies that the user has SELECT privilege on some_view (via the ACL in pg_class.relacl).

-- Does not check the user’s privileges on the underlying tables (unless the view is SECURITY INVOKER with explicit flags—by default, views run with the caller’s privileges only on the view object itself).

-- Security Definer vs. Security Invoker (for Functions/Views)

-- Though views do not have a direct SECURITY DEFINER flag, the concept applies indirectly: views always execute as if the view’s owner ran the underlying SELECT. The calling user need not have privileges on underlying tables.

-- The planner substitutes a view’s query into the caller’s query and temporarily “switches” to the view owner’s privilege to check access to base tables; this happens transparently.

-- Revoking Direct Table Access

-- Since the view is executed with the owner’s privileges on the base table, it’s crucial that you revoke or never grant privileges on base tables to untrusted roles. Otherwise, they could query the base tables directly.

-- Dependency Tracking for Privileges

-- When you grant privileges on a view, PostgreSQL records that ACL in pg_class.relacl. There’s also a dependency entry (pg_depend) noting that the view depends on the base table.

-- If you DROP or ALTER a base table in a way that invalidates the view, PostgreSQL checks dependencies and prevents the change unless you use CASCADE.

-- Example Query to Inspect a View’s ACL:

SELECT relname, relacl
  FROM pg_class
 WHERE relkind = 'v'
   AND relname = 'employee_public';

-- The relacl column might show something like {analyst=r/owner,owner=arwd*/owner}.

-- Using views for Row-Level Security (RLS) vs PostgreSQL's Built-In RLS

-- Dynamic, Per-Row Checks Based on Session Variables

-- RLS policies can reference current_user, current_setting(...), or jwt.claims.* (when using certain authentication extensions) to allow only rows matching the current user’s identity.

-- Example:

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY orders_user_policy
  ON orders
 USING (customer_id = current_setting('app.current_customer_id')::INT);

-- Application sets: SET app.current_customer_id = '12345';
SELECT * FROM orders;  -- returns only rows for customer_id = 12345

-- Complex Predicate Combinations

-- RLS can combine multiple policies (USING vs. WITH CHECK) for different operations (SELECT vs. INSERT/UPDATE/DELETE).

-- Very granular control over which operations are allowed per user or role.

-- Simplicity in Schema Management

-- When using RLS, you don’t need to maintain multiple views per role or per filter criterion. You define policies once and grant roles access to the base table; policies enforce row filters automatically.

-- When Views Still Make Sense

-- Schema-Level Abstraction for Auditors or External Consumers

-- If you’re sharing read-only access with auditors or BI teams, and you want to hide internal RLS logic or simplify table structures, a view can present a sanitized, narrow subset of columns/rows.

-- Example: A view that already filters sensitive columns and row subsets, while RLS enforces additional internal rules.

-- Enforcing Column-Level Security

-- RLS is about rows, not columns. If you need to hide columns entirely (e.g., salary or SSN), a view is still the best approach.

-- Legacy Systems or Third-Party Tools

-- Some reporting tools or ORM layers expect views rather than relying on PostgreSQL’s RLS. In such cases, views can provide the necessary interface.

-- Performance Considerations

-- A well-indexed view can be faster than dynamic RLS policies in some scenarios, especially when you combine with materialized views for summaries, then layer on simple filters via regular views for each role.

-- Example: Combining RLS and Views

-- Base Table with RLS

CREATE TABLE transactions (
  txn_id       SERIAL PRIMARY KEY,
  user_id      INT NOT NULL,
  account_id   INT NOT NULL,
  amount       NUMERIC(12,2) NOT NULL,
  timestamp    TIMESTAMP NOT NULL,
  internal_flag BOOLEAN NOT NULL DEFAULT false
);

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_transaction_policy
  ON transactions
 USING (user_id = current_setting('app.current_user_id')::INT)
WITH CHECK (user_id = current_setting('app.current_user_id')::INT);

-- View to hide Internal flags

CREATE VIEW user_transactions_public AS
  SELECT txn_id, account_id, amount, timestamp
    FROM transactions;

GRANT SELECT ON user_transactions_public TO public_viewer;

-- How it works at runtime: 

SET app.current_user_id = '42';
SELECT * FROM user_transactions_public WHERE amount > 100;

-- PostgreSQL verifies the caller has SELECT on user_transactions_public.

-- Inlines the view’s query: SELECT txn_id, account_id, amount, timestamp FROM transactions.

-- Applies RLS policy’s USING (user_id = 42) automatically, even though user_id isn’t selected.

-- Evaluates the amount > 100 filter.

-- As a result, the user sees only their own transactions (due to RLS) and still only the columns exposed by the view.

-- Practices

-- Revoke All Privileges on Base Tables

-- Never grant SELECT (or other DML) on base tables to roles that should only see data via views. Otherwise, they can bypass your views entirely.

REVOKE ALL ON employees FROM analyst;
REVOKE ALL ON SCHEMA private FROM analyst;

-- Use Separate Schemas for Protected Data

-- Place sensitive tables in a schema (private) with no USAGE for untrusted roles. Place the corresponding views in a separate schema (public or reports) where you do grant USAGE.

-- Avoid “Leaky” Views

-- Be cautious with SELECT * in a view on a table containing new or altered columns over time. If you add a sensitive column later (salary, SSN), it will automatically appear in existing views defined as SELECT *, potentially exposing it.

-- Best Practice: Explicitly list columns in your view definitions.

-- Beware of Policy Overrides with Security-Barrier Views

-- If you rely on RLS and create a view marked WITH (security_barrier), PostgreSQL will prevent predicate pushdown. This is often desired (to avoid filter bypass), but can sometimes lead to suboptimal plans.

-- Pitfall: Complex filters in both RLS policies and view definitions may block the optimizer from using indexes effectively.

-- Document View-Based Security Layers

-- As your database evolves, it’s easy to lose track of which view filters what. Maintain a simple inventory:

-- View name

-- Underlying tables

-- Columns/rows filtered

-- Roles granted access

-- This documentation prevents accidental privilege escalation or data leakage when views are altered.

-- Combine RLS for Row Filters and Views for Column Hiding

-- In scenarios where you need both per-user row filtering (dynamic) and column hiding (static), use RLS policies on the base table + a view exposing only safe columns. This ensures you minimize exposure and simplify maintenance.

-- Testing Before Deployment

-- Always test as a “least-privileged” role. For example:

CREATE ROLE test_user NOLOGIN;
GRANT SELECT ON employee_public TO test_user;
SET ROLE test_user;
\dt               -- should not list private tables
SELECT * FROM employee_public;  -- should work
SELECT * FROM employees;        -- should fail
RESET ROLE;


