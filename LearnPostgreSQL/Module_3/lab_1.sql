-- 

-- Anatomy of a PL/pgSQL function.

CREATE OR REPLACE FUNCTION hello_world(name TEXT)
  RETURNS TEXT
  LANGUAGE plpgsql
AS $$
BEGIN
  RETURN 'Hello, ' || name || '!';
END;
$$;

-- Signature:

-- hello_world(name TEXT) declares one parameter, name of type TEXT.

-- RETURNS TEXT indicates it returns a single TEXT value.

-- Language Clause:

-- LANGUAGE plpgsql tells PostgreSQL to use its procedural interpreter (PL/pgSQL).

-- Function Body:

-- Enclosed in $$ … $$.

-- The BEGIN … END block contains procedural steps; here, we simply concatenate strings and return.

SELECT hello_world('David');
-- Result: hello_world 
--        ---------------
--        Hello, David!

-- Parsing

-- When you issue CREATE FUNCTION, PostgreSQL parses the SQL, validates the signature (parameter types, return type), and stores the function definition catalog entries in pg_proc. It does not immediately compile PL/pgSQL code into machine code; instead, it preserves your source text.

-- Planning at First Call

-- On the first SELECT hello_world('Alice'), PostgreSQL parses the function-call SQL, binds the argument 'Alice' to the TEXT parameter, and then planners the inner PL/pgSQL code. PL/pgSQL code is parsed into an internal structure called a parse tree.

-- Execution
    
-- PL/pgSQL’s interpreter walks the parse tree.

-- It evaluates expressions (e.g., string concatenation), manages local variables (if any), and invokes built-in operators/functions.

-- Finally, it returns the result to the SQL engine, which formats and sends it back to the client.

-- Subsequent Calls Use Cached Plans

-- After that first call, PostgreSQL caches a compiled plan for the PL/pgSQL block. Future calls bypass reparsing the function’s body, so they run faster.

-- Create a “safe division” function that returns NULL if division by zero is attempted:

CREATE OR REPLACE FUNCTION safe_divide(a NUMERIC, b NUMERIC)
  RETURNS NUMERIC
  LANGUAGE plpgsql
AS $$
BEGIN
  IF b = 0 THEN
    RETURN NULL;
  ELSE
    RETURN a / b;
  END IF;
END;
$$;

-- Test various inputs:
SELECT safe_divide(10, 2);  -- Expect 5
SELECT safe_divide(10, 0);  -- Expect NULL
SELECT safe_divide(7.5, 2.5);  -- Expect 3

-- Observe EXPLAIN ANALYXE on a call 
EXPLAIN ANALYZE SELECT safe_divide(100, 5);

--Notice that the cost of invoking a procedural function like this is higher than a plain SQL expression, due to the PL/pgSQL interpreter overhead.

-- You’ll see a node like Function Scan on safe_divide(a, b) in the plan—indicating that PostgreSQL is treating the function invocation as a separate execution unit.

