-- Syntax for CREATE VIEW and basic examples.

CREATE [OR REPLACE] VIEW view_name (column_alias[, ...])
as 
  SELECT ...
  FROM ...
  [WHERE]
  [GROUP BY]
  [HAVING]
  [WITH [NO] CHECK OPTION];

-- CREATE VIEW view_name: Defines a new view called view_name.

-- OR REPLACE: If a view with this name already exists, it replaces the definition (preserving existing privileges)

-- (column_alias,...): Optionally renames the output columns. If omitted, PostgreSQL uses the column names from the SELECT.

-- AS SELECT ...: The query whose result set you want the view to present.

-- WITH CHECK OPTION: Enforces that any INSERT or UPDATE through this view must satisfy the view's WHERE clause.

-- 1. Simple Projection

-- Suppose you have a table:
CREATE TABLE products (
  product_id SERIAL PRIMARY KEY,
  name TEXT,
  category TEXT,
  price NUMERIC(10, 2),
  in_stock BOOLEAN DEFAULT true
);

-- To create a view showing only product names and prices:
CREATE VIEW product_prices AS 
  SELECT product_id, name, price
    FROM products;

-- What this does and why it works: 

-- Defines product_prices with exactly three columns- product_id, name, and price

-- Any SELECT * FROM product_prices is syntatic sufar for re-running that underlying SELECT each time.

-- On creation, PostgreSQL records this SELECT's parse tree in system catalogs (pg_rewrite).

--When you query product_prices, the planner simply inlines SELECT product_id, name, price FROM products into your outer query.

-- 2. Join-Based view

-- Given two tables, customers and orders:
CREATE TABLE customers (
  customer_id PRIMARY KEY,
  first_name TEXT,
  second_name TEXT,
  signup_date DATE
);

CREATE TABLE orders (
  order_id PRIMARY KEY,
  customer_id INT REFERENCES customers(customer_id),
  order_total NUMERIC(10,2),
  placed_at TIMESTAMP
);

-- Create a view that shows customer full names alongside their total order amounts:
CREATE OR REPLACE VIEW customer_orders_totals AS 
  SELECT 
    c.customer_id, c.first_name ||''|| c.last_name as full_names,
    SUM(o.order_total) AS total_spent
  FROM customer c
  JOIN orders o ON o.customer_id = c.customer_id
  GROUP BY c.customer, c.first_name, c.last_name;

-- Clients can run SELECT * FROM customer_order_totals WHERE total_spent > 1000l; without having to write the oin and GROUP BY themselves

-- Under the hood PostgreSQL stores the join and aggregation logic. When you query the view, it rewrites your request into a combined plan:

SELECT 
  c.customer_id, c.first_name ||''|| c.last_name AS full_name
  SUM(o.order_total) AS total_spent
FROM customer.c
JOIN orders o on o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING SUM (o.order_total) > 1000;

-- If you add a filter in your query against the view:
SELECT full_name, total_spent
  FROM customer_order_totals
  WHERE total_spent BETWEEN 500 AND 1000;

-- PostgreSQL inlines this so that the BETWEEN 500 and 1000 condition is appended to the origiginal aggregation query. The combined SQL Becomes:

SELECT 
  c.customer_id, c.first_name ||''|| c.last_name AS full_name, 
  SUM(o.order_total) AS total_spend
FROM customer c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING SUM(o.order_total) BETWEEN 500  AND 1000;

-- The optimizer can push down filters into aggregation or even to underlying scans where possible

-- 3. Reflecting changes in base tables.

INSERT INTO products(name, category, prices) VALUES
  ('Laptop', 'Electronics', 1200.00),
  ('Mouse', 'Electronics', 25.00),
  ('Notebook', 'Stationery', 5.00);

CREATE VIEW cheap_products AS 
  SELECT prouduct_id, name, price
    FROM products
  WHERE price < 100;

SELECT * FROM cheap_products;
--RETURNS:
-- product_id |   name    | price 
-----------------------------
--     2        Mouse       25.00
--     3        Notebook    5.00 

-- Update base table

UPDATE products
  SET price = 150
WHERE name = 'Mouse';

-- Add a new cheap product

INSERT INTO product (name, category, price) VALUES 
  ('Pen', 'Stationery', 2.50);

SELECT * FROM cheap_products;
-- Now returns:
-- product_id |   name    | price 
-----------------------------
--     4        Notebook    5.00 
--     5        Pen         2.50 

-- A regular view contains no stored data. Every time you hit cheap_products, PostgreSQL re-runs SELECT product_id, name, price FROM products WHERE price < 100 and show the current state. 



