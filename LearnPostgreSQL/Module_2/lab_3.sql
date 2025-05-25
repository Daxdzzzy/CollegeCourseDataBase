-- Modifying and dropping views

-- 1. Simple alteration: adding a filter, in the backend module we created the view for active_employees. Management has now decided to exclude the 'HR' department from this view as well.

CREATE OR REPLACE VIEW active_employees AS
  SELECT employee_id, first_name, last_name, department, city
    FROM employees
  WHERE active = true
    and deparment <> 'HR';

-- PostgreSQL looks up the existing "rewrite rule" for active_employees in pg_rewrite

-- It validates the new SELECT, ensuring column tupes and names match what's already stored in pg_attribute (unless you also changed aliases)

-- It updates the rewrite rule's stored parse tree. Dependents objects (sucj as other views built on top of active_employees) are checked to ensure they still compile.

-- 2. Changing column order or names

-- original view
CREATE VIEW product_prices AS
  SELECT product_id, name, price
    FROM products;
-- You want the column order to be (name, price, product_id) and rename price to unit_price. Do:

CREATE OR REPLACE VIEW product_prices (name, unit_price, product_id) AS 
  SELECT name, price, product_id
    FROM products;

-- The SELECT must still return three columns, in the same order as your alias list.

-- PostgreSQL replaces stored column names in pg_attribute fot this view. Any queries that referenced the old price column name will now fail until updated

-- Dependent objects: If another view or view function depends on product_prices.price, phasing it out by renaming could break those downstream objects

-- If you try to REPLACE a view in a way that changes column count or type, PostgreSQL will error with something like:
--ERROR:  view product_prices cannot be replaced because column "unit_price" is of type numeric but the stored definition expects type ...

-- Privileges: When you replace a view, any existin GRANTs stay in place. If you'd dropped and recreated you'd need yo re-grant privileges.

-- 3. ALTER VIEW Renaming and Granting

-- Renaming a view  ALTER VIEW old_view_name RENAME TO new_view_name;

ALTER VIEW  product_prices RENAME TO product_catalog;

-- Updates pg_class_relname for that view.

-- dependencies update automatically (PostgreSQL tracks by object OID, not by name), so any queries referencing product_prices will now need to use product_catalog. Dependent objects will show invalid until recompiled or updated

-- Altering view owner or schema: ALTER VIEW view_name SET SCHEMA new_schema; ALTER VIEW view_name OWNER TO new_owner;

CREATE SCHEMA reports;
ALTER VIEW active_employees SET SCHEMA reports;

-- PostgreSQL updates pg_class.relnamespace accordingly.

-- Granting Priviles on a View
GRANT SELECT [( column_list )] on view_name TO rol_name; 
REVOKE ALL ON view_name FROM PUBLIC;

-- Allow analysts only to see product prices, not moidify anything

GRANT SELECT (product_id, name, unit_price) ON 
product_catolog TO analystic_team
REVOKE ALL ON product_catalog FROM PUBLIC;

-- PostgreSQL stores these privileges in pg_class.relacl (ACL ARRAY).

-- Users with only SELECT on the view cannot access unerlying products table unless they also have direct privileges on it.

-- 4. Dropping a view safely

-- Basic DROP VIEW SYNTAX

DROP VIEW [IF EXISTS] view_name [cascade | RESTRICT]

-- IF EXISTS: Prevents an error if the view doesn't exist

-- RESTRICT (DEFAULT): Refuses to drop if there are any dependent objects.

-- CASCADE: Automatically drops dependent objects (child views, rules) as well

DROP VIEW active_employees;

-- If no other view, function, or rule depends on it, PostgreSQL removes its entry from pg_class and all associated antries in pg_rewrites and pg_depend.

-- If it's referenced by another view (for example, sales_team_employees was defined as SELECT * FROM active_employees WHERE department = 'sales'), you'll see:

--ERROR:  cannot drop view active_employees because other objects depend on it
--DETAIL:  view sales_team_employees depends on view active_employees
--HINT:  Use DROP ... CASCADE to drop the dependent objects too.

-- Dropping with cascade

DROP VIEW sales_team_employees CASCADE;

-- Drops both sales_team_employees and any objects that depend on it (e. g., rules, indexes on a materialized version, etc.).

-- PostgreSQL walks pg_depend entries to find all downstream dependets.

-- Using IF EXISTS

DROP VIEW IF EXISTS old_view_name;

-- Avoid errors if old_view_name doesn't exist. Useful in deployment scripts where view may or may not be present.

-- Dependency tracking : When you CREATE VIEW A AS SELECT ... FROM B, PostgreSQL inserts a dependency record in pg_depend linking A -> B (A depends on B)
-- If B is another view( say, B depends on C) , then A trnsitively depends on C. A chain of dependencies exists in pg_depend and pg_rewrite

-- What happens on DROP

-- RESTRICT: PostgreSQL checks pg_depend for any object where refclassid=class_of(A) and refobid=oid_of(A). If any rows exist (menaing something depends on A), drop is refused.

-- CASCADE: PostgreSQL collects all dependent objects by traversing pg_depend recursively, then drops them in reverse order: children first, parent last.

-- BEST PRACTICE: 
-- Before dropping a view, run : 


SELECT
  depnsp.nspname AS dependent_schema,
  depcls.relname  AS dependent_object,
  class_nsp.nspname AS dependency_schema,
  class_cls.relname AS dependency_object
FROM pg_depend d
JOIN pg_class depcls ON depcls.oid = d.objid
JOIN pg_class class_cls ON class_cls.oid = d.refobjid
JOIN pg_namespace depnsp ON depnsp.oid = depcls.relnamespace
JOIN pg_namespace class_nsp ON class_nsp.oid = class_cls.relnamespace
WHERE class_cls.relname = 'active_employees'  -- your view name
  AND class_cls.relkind = 'v';

-- This query helps you see exactly which objects depend on active_employees so you can decide if you really want to cascade.


