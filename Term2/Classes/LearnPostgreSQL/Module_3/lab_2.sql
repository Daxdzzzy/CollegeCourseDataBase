-- Parameter modes in PL/pgSQL

-- By default, every parameter you declare in a PL/pgSQL function is an input parameter (IN)—meaning the caller passes a value, and you cannot change it inside the function (it’s read-only). PostgreSQL also supports:

-- OUT parameters:

--Acts like output variables. When you declare an OUT parameter, it becomes a local variable inside the function. You assign to it, and at function exit, PostgreSQL returns any OUT parameters as a row.

-- You can have multiple OUT parameters—PostgreSQL will implicitly package them as a composite record.

-- INOUT parameters:

-- Combines IN and OUT: the caller can pass an initial value, and the function can modify it. On exit, the modified value is returned.

-- Internally, INOUT parameters are treated as local variables that are initialized to the passed-in value.

CREATE OR REPLACE FUNCTION split_name(
  fullname TEXT,
  OUT first_name TEXT,
  OUT last_name TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
  first_name := split_part(fullname, ' ', 1);
  last_name  := split_part(fullname, ' ', 2);
  -- No explicit RETURN needed; POSTGRES will RETURN (first_name, last_name)
END;
$$;

-- fullname TEXT is an IN parameter.

-- first_name and last_name are declared as OUT TEXT; they automatically become local, assignable variables.

-- There is no RETURNS clause with a type—PostgreSQL infers the return type as a composite (first_name TEXT, last_name TEXT).

SELECT * FROM split_name('Ada Lovelace');
--  first_name | last_name
-- ------------+----------
--  Ada        | Lovelace

-- If you call SELECT split_name('Ada Lovelace'); (without *), PostgreSQL returns a composite value like ("(Ada,Lovelace)", ). It’s usually clearer to use SELECT * to see each column.

-- Function with INOUT parameter.

CREATE OR REPLACE FUNCTION add_tax_amount(
  INOUT net_amount NUMERIC,
  tax_rate NUMERIC
)
LANGUAGE plpgsql AS $$
BEGIN
  net_amount := net_amount + (net_amount * tax_rate);
  -- At exit, net_amount holds the updated (gross) value, and that is returned.
END;
$$;

SELECT add_tax_amount(100.00, 0.15);
-- Returns 115.00

-- Internally, net_amount starts as 100.00 (passed in), then the function updates it to 115.00, and that final value is returned.

-- Variable declararion and scoping rules

-- You can declare local variables just after the AS $$ and before de BEGIN, e.g.;

CREATE OR REPLACE FUNCTION compute_stats(numbers INT[])
  RETURNS NUMERIC
  LANGUAGE plpgsql AS $$
DECLARE
  total   NUMERIC := 0;
  counter INT     := 0;
  avg_val  NUMERIC;
BEGIN
  FOREACH counter IN ARRAY numbers LOOP
    total := total + counter;
  END LOOP;
  IF array_length(numbers, 1) > 0 THEN
    avg_val := total / array_length(numbers, 1);
  ELSE
    avg_val := NULL;
  END IF;
  RETURN avg_val;
END;
$$;

-- Initialization: You can assign a default value (:= 0). If you don’t initialize, PostgreSQL defaults numeric types to NULL, integer types to NULL, text to NULL, etc.

-- Scope:

-- Function-level variables (declared in the DECLARE block) live for the entire function invocation.

-- If you create a nested block inside the BEGIN … END, you can redeclare variables (shadows outer names) and those inner variables only live inside that block.

BEGIN
  DECLARE
    x INT := 1;
  BEGIN
    -- This is a nested block
    DECLARE
      x INT := 5;  -- shadows outer x
    BEGIN
      RAISE NOTICE 'Inner x = %', x;  -- prints 5
    END;
    RAISE NOTICE 'Outer x = %', x;  -- prints 1
  END;
END;

-- At function startup, PostgreSQL allocates a memory context for the invocation. All local variables are stored in that context.

-- Nested blocks create sub-contexts; once you END a block, its sub-context is freed, preventing memory leaks.

-- At function exit, the entire function context is deallocated.

-- Execution flow 

-- CREATE FUNCTION Time

-- PostgreSQL stores the function signature, parameter modes, and the source text in pg_proc.

-- It does not yet parse the PL/pgSQL; it simply keeps the body as plain text.

-- First Invocation

-- You call, for example, SELECT split_name('Grace Hopper');.

-- PostgreSQL parses that SQL, matches "split_name" to a pg_proc entry, and binds the literal 'Grace Hopper' to the IN fullname parameter (type-checking happens now).

-- PL/pgSQL’s parser then takes the function body and produces an internal parse tree (an abstract syntax tree).

-- It converts that parse tree into a plan tree, then into lower-level execution steps. For parameter-mode functions:

-- IN parameters are placed into read-only slots.

-- OUT parameters are created in a separate tuple slot; they default to NULL until you assign.

-- INOUT parameters get an initial slot set to the caller’s value.

-- Interpreter Loop

-- The PL/pgSQL interpreter visits each node in the plan tree.

-- When it sees an assignment to an OUT or INOUT variable, it updates the tuple slot.

-- Control structures (IF, LOOP, FOREACH, etc.) map to interpreter opcodes, which the engine executes one by one.

-- Return & Cleanup

-- When you RETURN; (in OUT-parameter functions) or RETURN expression; (in RETURNS-type functions), PostgreSQL fetches the values from the OUT (or result) slots, packages them into a tuple, and returns it to the SQL layer.

-- The function’s memory context is freed—all local variables (including nested-block variables) are deallocated at once.

-- Hands-On execise 

-- Creating and testinf an IN/OUT Function

CREATE TABLE sales (
  id       SERIAL PRIMARY KEY,
  amount   NUMERIC NOT NULL,
  sale_dt  DATE    NOT NULL
);

INSERT INTO sales (amount, sale_dt) VALUES
  (100.00, '2025-01-05'),
  (250.00, '2025-01-10'),
  (75.00,  '2025-02-05'),
  (300.00, '2025-02-20');

-- Write a Function with OUT Parameters to compute total sales and average sale for a given month:


CREATE OR REPLACE FUNCTION monthly_sales_stats(
  in_year  INT,
  in_month INT,
  OUT total_sales   NUMERIC,
  OUT avg_sale_amt NUMERIC
)
LANGUAGE plpgsql AS $$
BEGIN
  SELECT SUM(amount),
         CASE WHEN COUNT(*)>0 THEN SUM(amount)::NUMERIC / COUNT(*) ELSE NULL END
    INTO total_sales, avg_sale_amt
    FROM sales
   WHERE EXTRACT(YEAR  FROM sale_dt) = in_year
     AND EXTRACT(MONTH FROM sale_dt) = in_month;
END;
$$;

-- Test the function:

-- January 2025:
SELECT * FROM monthly_sales_stats(2025, 1);
--  total_sales | avg_sale_amt
-- -------------+--------------
--      350.00  |        175.00

-- February 2025:
SELECT * FROM monthly_sales_stats(2025, 2);
--  total_sales | avg_sale_amt
-- -------------+--------------
--      375.00  |      187.50

-- A month with no sales:
SELECT * FROM monthly_sales_stats(2025, 3);
--  total_sales | avg_sale_amt
-- -------------+--------------
--      NULL    |      NULL

-- When there are no matching rows, both total_sales and avg_sale_amt remain NULL (because SUM() over zero rows is NULL; dividing would also be bypassed by the CASE).

-- EXPLAIN ANALYZE on One Call:

EXPLAIN ANALYZE SELECT * FROM monthly_sales_stats(2025, 1);

-- You will see something like: 

Function Scan on monthly_sales_stats(year, month)  (cost=0.00..1.23 rows=1 width=32) (actual time=0.012..0.013 rows=1 loops=1)
  Output: total_sales, avg_sale_amt
Planning Time: 0.055 ms
Execution Time: 0.045 ms

-- “Function Scan on monthly_sales_stats”: shows that PostgreSQL treats the entire monthly_sales_stats invocation as a single node.


-- Loads the IN parameters (2025 and 1).

-- Executes the SELECT SUM(...) … INTO total_sales, avg_sale_amt ….

-- Writes results into the OUT slots.

-- Returns the one-row result containing (total_sales, avg_sale_amt).
