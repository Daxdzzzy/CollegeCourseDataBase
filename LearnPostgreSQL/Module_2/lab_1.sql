-- 1. What's and sql view? 

-- A view is essentially a saved sql query that you can treat like a table. In PostgreSQL, when you write: 

CREATE VIEW staff_locations AS
  SELECT employee_id, department, city
    FROM employees
   WHERE active = true;

-- The database stores that SELECT statement under the name staff_locations. When you later run: 

SELECT * FROM staff_locations WHERE city = 'Bogota';

-- PostgreSQL expands that view into its underlying employees query behind the scenes.

-- Why it matters: 

-- PostgreSQL does not store the view's data separately (unless you create a materialized view; we''ll cover that later). Instead, a view is stored as a parsed query tree in the system catalog (pg_class, pg_views, etc). 

-- At run time, when you query the view, the query planner will "inline", the view's definition into your new query, optimizing as though you had written the full SELECT yourself, In other words, the view's SQL is merged into your outer query, producing a single execution plan.

-- This means there's no additional storage overhead for a regular view: its purely a layer of abstraction.

-- 2. Benefits of using a view.

-- a) Abstraction and simplicity: 

-- Hides complex joins or business-logic filters behind a simple "virtual table" 

-- Developers can SELECT * FROM customer_orders without knowing ther underlying JOIN customers ... JOIN orders ... details... 

-- b) Security and access control: 

-- You can grant users SELECT privileges on a view without giving them direct access to base tables.

-- By exposing only certain columns (or rows) in the view, you prevant unauthorized access to sensitive fields. 

-- c) Maintainability: 

-- If your business logic changes say you need to exclude archived records you can modify the view definition in one place rather than update every query in application code.

-- d) Consistency:

-- By centralizing a common query into a view, you ensure every part of the application uses the same filters and joins, avoiding drift over time.

-- 3. How PostgreSQL handles a view internally.

-- a) Storage: 

-- When you run CREATE VIEW, PostgreSQL records: 

-- The view name and owner in pg_class. 

-- The view's query in pg_written as a "rewrite rule"  (essentially a stored parse tree).

-- Metadata about columns in pg_attribute (data types, name).

-- b) parsing and planning: 

-- View definition stored: At creation time, PostgreSQL parses the view's SELECT to validate syntax and column types. 
 
-- Runtime inlining: When you run SELECT * FROM staff_locations WHERE city = 'Bogota', the planner:

-- Open the rewrite rule for staff_locations.

-- Substitutes the view's origin SELECT (SELECT  employee_id, department, city FROM employees WHERE active = true) into the outer query's  WHERE clause, effectively producing:

SELECT employee_id, department, city FROM employees
  WHERE active = true and city = 'Bogota';

-- Optimizes that combined query pushing filters down, choosing indexes, etc... 

-- NO materialization: Becuase a plain view has no stored data, every reference to the view re-executes its underlying query. This make views lightweight but means they always show live data and incur the cost of computing the query each time. 

-- 4. Hands-on 

-- a) Create a simple view. 

-- Connect to your test database (we have been working, practicing, and learning using this proj_db database) 

-- Step 1 Create a sample table.

CREATE TABLE employees (
  employee_id SERIAL PRIMARY KEY,
  first_name VARCHAR(50),
  last_name VARCHAR(50),
  department VARCHAR(50),
  city VARCHAR(50),
  active BOOLEAN DEFAULT true,
);

INSERT INTO employees (first_name, last_name, department, city, active) VALUES 
  ('Ana', 'García', 'Sales',      'Bogotá', true),
  ('Luis', 'Ramírez', 'Engineering', 'Medellín', true),
  ('María', 'Sánchez', 'HR',         'Cali', false),
  ('Jorge', 'Pérez', 'Sales',      'Cartagena', true);

-- Step 2 Define a view that shows only active employees.

CREATE VIEW active_employees AS
  SELECT * FROM employess
    WHERE active = true;

-- b) Querying the view

-- Behind the scenes, PostgreSQL will take this: 
SELECT * FROM active_employees WHERE department = 'Sales';
-- and rewrite it as: 
SELECT employee_id, first_name, last_name, department, city FROM employees
  WHERE active = true and department = 'Sales';

-- c) Verifying the view's definition 

-- You can inpsect the stored query by querying the system catalogs:
SELECT definition FROM pg_views
  WHERE viewname = 'active_employees';

-- d) Seeing that it's always live

-- Initially:
SELECT * FROM active_employees;
-- Returns 3 rows (Ana, Luis, Jorge)

-- Disable one employee:
UPDATE employees
    SET active = false
  WHERE first_name = 'Jorge';

-- Now re-query the view:
SELECT * FROM active_employees;
-- Returns only Ana and Luis (view reflects the change immediately).


