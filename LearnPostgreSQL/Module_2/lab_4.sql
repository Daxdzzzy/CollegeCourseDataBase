-- Updatable views and with check option

-- 1. Criteria for a view to be updatable

-- a) PostgreSQL supports "simple" updatable views natively, but only when the view satisifes certain requirements. When a view is updatable, PostgreSQL implicitly rewrites DML against the view into DML agaisnt the base table(s). 

-- The view must select form exactly one table (no joins, aggreagares or set operations)

CREATE VIEW active_products AS 
  SELECT product_id, name, price
    FROM products
  WHERE in_stocks = true;

-- This view is based solely on products and simply filters rows.

-- b) No expression on selected columns (Except for Column renames):

-- Each collumn in the view must correspong directly to a column in the base table, except you may rename.

-- ALLOWED
CREATE VIEW v AS
  SELECT col1 AS a, col2 AS b
    FROM table 1;

-- NOT ALLOWED
CREATE VIEW v_bad AS
  SELECT col1, (col2 + 0) AS b
    FROM table1;

-- c) No DISTINCT, GROUP BY, HAVING, UNION, LIMIT, OFFSET, or Window functions

-- Rhese constructs aggreagate or rearrange data in ways that cannot be mapped back to individual rows of the base table.

-- A view defined whit anddy of these clauses is considered read only.

-- d) ALL NOT NULL columns must appear in the view (or have defaults):

-- If the base table has columns declared NOT NULL and no default exists, the view must expose those columns. Otherwise, and insert through the view might attempt to write a NULL into a NOT NULL column

-- Alternatively, the base table could hava a default for that column, allowing omission form the view.

-- e) No WITH queries (CTEs) or subqueries in the select list

-- CTEs and subqueries break the direct mapping to base-table columns. If you need to hide logic, consider using a view on top of an already-updatable view, but be aware you may lose updatability if you introduce a subquery.

-- d) View definition is not marked as SECURITY_BARRIER:

-- Security barrier views prevent certain optimizations and render the view read-only (We'll conver security-barrier views when discussing RLS.)

-- 2. Performing DML through an updatable view

-- Assume we have a base table: 
CREATE TABLE inventory (
  item_id    SERIAL PRIMARY KEY,
  name       TEXT NOT NULL,
  quantity   INTEGER NOT NULL,
  location   TEXT NOT NULL,
  in_stock   BOOLEAN NOT NULL DEFAULT true
);

-- Let's create a view to shoe only in stock items:
CREATE VIEW in_stock_inventory AS
  SELECT item_id, name, quantity, location
    FROM inventory
  WHERE in_stock = true;

-- Because this view meets the updatability criteria (single base table, no expressions, no aggreagation, ALL NOT NULL columns appear or have defaults), we can perfom the followin;

-- INSERT via the view

-- Insert a new in-stock item
INSERT INTO in_stock_inventory (name, quantity, location)
VALUES ('Widget A', 100, 'Warehouse 1');

-- What happens practically? PostgreSQL rewrites this to:
INSERT INTO inventory (name, quantity, location, in_stock)
VALUES ('Widget A', 100, 'Warehouse 1', true);

-- in_stock is set to true implicitly (because the view's predicate is in_stock = true).

-- After insertion, the new row appears in both inventory and in_stock_inventory.

-- During view creation, PostgreSQL builds a rule in pg_rewrite such as:

ON INSERT TO in_stock_inventory DO INSTEAD
  INSERT INTO inventory (name, quantity, location, in_stock)
    VALUES (NEW.name, NEW.quantity, NEW.location, true);

-- Update via the view

-- Increase quantity for item_id = 5
UPDATE in_stock_inventory
  SET quantity = quantity + 10
WHERE item_id = 5;

-- PostgreSQL rewrites to 
UPDATE inventory
   SET quantity = quantity + 10
 WHERE item_id = 5
   AND in_stock = true;

-- if in_stock were false, the AND in_stock = true condition would prevent the update from matching, ensuring you can't update a row that isn't visible in the view.

-- Rewrite rule similar to: 
ON UPDATE TO in_stock_inventory DO INSTEAD
  UPDATE inventory
     SET quantity = NEW.quantity, name = NEW.name, location = NEW.location
   WHERE inventory.item_id = OLD.item_id
     AND inventory.in_stock = true;

-- DELETE via the view

DELETE FROM in_stock_inventory
  where item_id = 7;

-- rewrites to 
DELETE FROM inventory
 WHERE item_id = 7
   AND in_stock = true;

-- Only rows that match both item_id = 7 and in_stock = true are deleted. If in_stock were false, nothing happens.

-- A rewrite rule in pg_rewrite turns the DELETE into an operation on the base table with the view’s predicate appended.

-- 3. Enforcing constraints with WITH CHECK OPTION 

-- While the automatic rules above enforce that DML adheres to the view’s predicates on existing rows, they do not prevent you from inserting or updating a row in a way that violates the view’s filter—unless you specify WITH CHECK OPTION. This option adds an extra check to guarantee that any new or changed row still satisfies the view’s WHERE clause.

-- SYNTAX
CREATE [ OR REPLACE ] VIEW view_name [( column_list ) ]
AS
  SELECT …
  FROM …
  WHERE <filter>
  WITH [ LOCAL | CASCADED ] CHECK OPTION;

-- WITH CHECK OPTION: Ensures that any inserted or updated row through the view continues to satisfy <filter>.

-- LOCAL versus CASCADED:

-- LOCAL limits the check to the immediate view’s WHERE clause.

-- CASCADED (the default) ensures the check applies to this view and any underlying views in its definition (if chaining views).

-- Using our previous in_stock_inventory view, suppose we modify it to:

CREATE OR REPLACE VIEW in_stock_inventory AS
  SELECT item_id, name, quantity, location
    FROM inventory
   WHERE in_stock = true
  WITH CHECK OPTION;


-- Now try the following: 

-- Attempt to insert a row that fails the predicate
INSERT INTO in_stock_inventory (name, quantity, location, in_stock)
VALUES ('Gadget B', 50, 'Warehouse 2', false);

-- Result:
ERROR:  new row for relation "inventory" violates check option for view "in_stock_inventory"
DETAIL:  Failing row contains (… in_stock = false).
-- Becuase false does not satisfy WHERE in_stock = true, WITH CHECK OPTION blocks the insert.


-- Update that violates the predicate
UPDATE in_stock_inventory
   SET in_stock = false
 WHERE item_id = 10;

-- Result:
ERROR:  modified row for view "in_stock_inventory" fails check option "in_stock_inventory"
DETAIL:  Failing row contains (… in_stock = false).

-- If you attempt to flip in_stock to false through this view. PostgreSQL block it because it would remove the row from the view's result set.

-- Successful insert though the view
INSERT INTO in_stock_inventory (name, quantity, location)
VALUES ('Gizmo C', 20, 'Warehouse 3');

-- The rewrite rule fills in_stock = true automatically.

-- Because true satisfies the view’s WHERE, the check option passes.

-- Row is inserted successfully into inventory.

-- LOCAL VS CASCADE

-- Consider two chained views:

CREATE VIEW v1 AS
  SELECT product_id, name, price
    FROM products
   WHERE price > 100;

CREATE VIEW v2 AS
  SELECT product_id, name
    FROM v1
   WHERE name LIKE 'A%';

-- If you add WITH CHECK OPTION to v2 only (default is CASCADED):

CREATE OR REPLACE VIEW v2 AS
  SELECT product_id, name
    FROM v1
   WHERE name LIKE 'A%'
  WITH CHECK OPTION;

-- Insert via v2:

-- The row must satisfy name LIKE 'A%' from v2’s own WHERE.

-- Because of CASCADED, it must also pass price > 100 from v1.

INSERT INTO v2 (product_id, name, price) 
VALUES (101, 'Alpha Gizmo', 80);

-- PostgreSQL will complain that price > 100 fails.

-- If you use WITH LOCAL CHECK OPTION on v2

CREATE OR REPLACE VIEW v2 AS
  SELECT product_id, name
    FROM v1
   WHERE name LIKE 'A%'
  WITH LOCAL CHECK OPTION;

-- Insert via v2: 

-- Only enforces name LIKE 'A%'.

-- It does not check price > 100. You could inadvertently insert (product_id=102, name='Aardvark', price=50).

-- That row would be visible in v2 (because Aardvark matches LIKE 'A%'), but violate v1’s filter at the base level.

-- In practice, PostgreSQL still prevents it, because the insert against v2 ultimately hits products, and the rule for v1 (which also has a check option, if defined) would block. If v1 had no check option, the row enters products and appears in v2 even though price <= 100. That undermines correctness


