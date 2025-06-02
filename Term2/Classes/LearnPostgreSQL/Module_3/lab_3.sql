-- Control flow constructs

-- syntax

IF condition THEN
  -- statements
ELSIF other_condition THEN
  -- statements
ELSE
  -- statements
END IF;

-- Example: 

CREATE OR REPLACE FUNCTION grade_letter(score NUMERIC)
  RETURNS TEXT
  LANGUAGE plpgsql AS $$
DECLARE
  result TEXT;
BEGIN
  IF score >= 90 THEN
    result := 'A';
  ELSIF score >= 80 THEN
    result := 'B';
  ELSIF score >= 70 THEN
    result := 'C';
  ELSIF score >= 60 THEN
    result := 'D';
  ELSE
    result := 'F';
  END IF;

  RETURN result;
END;
$$;

-- PL/pgSQL compiles each condition into a test opcode; then branches to the appropriate “label” for that block.

-- After assigning result, the interpreter jumps to the common exit point of the IF construct.


SELECT grade_letter(85);  -- returns 'B'
SELECT grade_letter(59);  -- returns 'F'

-- CASE Expression

-- Simple CASE

CASE expr
  WHEN val1 THEN res1
  WHEN val2 THEN res2
  ELSE res_default
END

-- Searched CASE

CASE
  WHEN cond1 THEN res1
  WHEN cond2 THEN res2
  ELSE res_default
END

-- Example searched CASE

CREATE OR REPLACE FUNCTION classify_temperature(temp NUMERIC)
  RETURNS TEXT
  LANGUAGE plpgsql AS $$
DECLARE
  category TEXT;
BEGIN
  category := CASE
    WHEN temp < 0   THEN 'Freezing'
    WHEN temp < 10  THEN 'Cold'
    WHEN temp < 20  THEN 'Cool'
    WHEN temp < 30  THEN 'Warm'
    ELSE              'Hot'
  END;

  RETURN category;
END;
$$;

-- The PL/pgSQL compiler transforms CASE into a series of conditional tests and jumps, similar to nested IF statements but optimized in the parse tree.

-- It often generates a decision tree: evaluate WHEN clauses in the order written, jumping to the matching branch or ELSE if none match.

-- Looping Constructs.

-- Syntax

FOR i IN 1..5 LOOP
  -- statements using i
END LOOP;

-- or reverse.

FOR i IN REVERSE 5..1 LOOP
  -- iterations: 5,4,3,2,1
END LOOP;

-- Example Summin the first N integers

CREATE OR REPLACE FUNCTION sum_first_n(n INT)
  RETURNS INT
  LANGUAGE plpgsql AS $$
DECLARE
  total INT := 0;
  i     INT;
BEGIN
  FOR i IN 1..n LOOP
    total := total + i;
  END LOOP;
  RETURN total;
END;
$$;

-- FOREACH element IN ARRAY array_var LOOP … END LOOP

FOREACH elem_var IN ARRAY some_array LOOP
  -- statements using elem_var
END LOOP;

-- Example: Concatenate elements of a text array 

CREATE OR REPLACE FUNCTION join_strings(items TEXT[])
  RETURNS TEXT
  LANGUAGE plpgsql AS $$
DECLARE
  result TEXT := '';
  item   TEXT;
BEGIN
  FOREACH item IN ARRAY items LOOP
    result := result || item || ',';
  END LOOP;
  -- Remove trailing comma (simplest approach)
  IF char_length(result) > 0 THEN
    result := left(result, char_length(result) - 1);
  END IF;
  RETURN result;
END;
$$;

-- PL/pgSQL obtains the array pointer, inspects its length, and iterates via an index from 1 to array_length.

-- Each iteration sets item := array_var[i].

-- WHILE condition loop... end loop

WHILE some_condition LOOP
  -- statements
END LOOP;

-- Example: Factorial using a WHILE loop

CREATE OR REPLACE FUNCTION factorial(n INT)
  RETURNS BIGINT
  LANGUAGE plpgsql AS $$
DECLARE
  fact BIGINT := 1;
  i     INT := 1;
BEGIN
  WHILE i <= n LOOP
    fact := fact * i;
    i := i + 1;
  END LOOP;
  RETURN fact;
END;
$$;

-- Exception Handling (BEGIN … EXCEPTION … END)

BEGIN
  -- risky operations
EXCEPTION
  WHEN specific_exception THEN
    -- handler for that exception
  WHEN another_exception THEN
    -- handler
  WHEN OTHERS THEN
    -- catch-all
END;

-- Reference names from the SQLSTATE error code catalog (e.g., unique_violation, division_by_zero, invalid_text_representation), or use group names like NO_DATA_FOUND.

CREATE TABLE users (
  id    SERIAL PRIMARY KEY,
  email TEXT UNIQUE NOT NULL
);

CREATE OR REPLACE FUNCTION insert_user_safe(p_email TEXT)
  RETURNS TEXT
  LANGUAGE plpgsql AS $$
DECLARE
  new_id INT;
BEGIN
  INSERT INTO users(email) VALUES (p_email) RETURNING id INTO new_id;
  RETURN 'Inserted with ID ' || new_id;
EXCEPTION
  WHEN unique_violation THEN
    RETURN 'Error: Email ' || p_email || ' already exists.';
  WHEN OTHERS THEN
    -- Log and re-raise unexpected errors
    RAISE;
END;
$$;

-- Attempt the INSERT. If no UNIQUE violation occurs, it proceeds past BEGIN to RETURN.

-- If a UNIQUE violation happens, control jumps immediately to the EXCEPTION block. PostgreSQL looks up the SQLSTATE code (23505) and matches it to unique_violation.

-- Executes the handler (RETURN 'Error …').

-- If an error doesn’t match any specified WHEN clause, it falls to WHEN OTHERS; here, we re-raise, causing the function to abort with the original error.

SELECT insert_user_safe('alice@example.com');  -- e.g., 'Inserted with ID 1'
SELECT insert_user_safe('alice@example.com');  -- 'Error: Email alice@example.com already exists.'

-- CURSORS

-- When you need to process rows one at a time, cursors let you fetch and loop explicitly instead of running a set-based query. This is useful when:

-- You need side effects per row (e.g., calling an external API).

-- The logic for each row is too complex to express in one SQL statement.

FOR record_var IN
  SELECT col1, col2 FROM some_table WHERE ...
LOOP
  -- use record_var.col1, record_var.col2
END LOOP;

-- Example: Grant a 10% bonus to each employee in a department

CREATE OR REPLACE FUNCTION apply_department_bonus(dept_id INT)
  RETURNS INT  -- number of employees updated
  LANGUAGE plpgsql AS $$
DECLARE
  emp   RECORD;
  counter INT := 0;
BEGIN
  FOR emp IN
    SELECT id, salary FROM employees WHERE department_id = dept_id
  LOOP
    UPDATE employees
       SET salary = salary * 1.10
     WHERE id = emp.id;
    counter := counter + 1;
  END LOOP;
  RETURN counter;
END;
$$;

-- When entering the FOR … IN SELECT loop, PL/pgSQL plans and executes the SELECT.

-- It opens an implicit cursor, fetches the first row into emp.

-- Executes the loop body, then fetches the next row, until no more rows.

-- Closes the implicit cursor automatically.

-- Explicit cursors.

DECLARE
  cur_emp CURSOR FOR
    SELECT id, salary FROM employees WHERE department_id = dept_id;
BEGIN
  OPEN cur_emp;
  LOOP
    FETCH cur_emp INTO emp_id, emp_salary;
    EXIT WHEN NOT FOUND;
    -- process emp_id, emp_salary
  END LOOP;
  CLOSE cur_emp;
END;

-- Batch-processing with explicit cursor

CREATE OR REPLACE FUNCTION reindex_large_table(batch_size INT)
  RETURNS VOID
  LANGUAGE plpgsql AS $$
DECLARE
  cur    CURSOR FOR SELECT oid::regclass::TEXT FROM pg_class WHERE relkind = 'r';
  tbl    TEXT;
  counter INT := 0;
BEGIN
  OPEN cur;
  LOOP
    FETCH cur INTO tbl;
    EXIT WHEN NOT FOUND;
    EXECUTE FORMAT('REINDEX TABLE %I;', tbl);
    counter := counter + 1;
    IF counter % batch_size = 0 THEN
      -- commit periodically to avoid huge transactions
      COMMIT;
      BEGIN
        -- Start a sub-transaction so that if one index fails, we continue
        EXECUTE 'SAVEPOINT reindex_sp';
      EXCEPTION WHEN OTHERS THEN
        -- Ignore errors on SAVEPOINT
        NULL;
      END;
    END IF;
  END LOOP;
  CLOSE cur;
END;
$$;

-- DECLARE cur simply registers the cursor definition; no query is run yet.

-- OPEN cur actually executes the SELECT … and initializes a result set in memory or on disk.

-- Each FETCH cur INTO … moves the pointer to the next row. When no rows remain, FOUND becomes FALSE.

-- You can choose to COMMIT or ABORT sub-transactions as needed; here, periodic commits prevent a massive long-running transaction.

-- Compilation Phase (First Invocation):

-- PL/pgSQL’s parser reads the function body, builds an AST including control-flow nodes (e.g., IfStmt, LoopStmt, CaseStmt, ExceptionStmt, CursorStmt).

-- It resolves all references to tables, columns, and functions (type checking).

-- Generates a plan tree (a sequence of opcodes) for each code block:

-- Conditional nodes map to PLPGSQL_STMT_IF, PLPGSQL_STMT_CASE opcodes.

-- Loop nodes map to PLPGSQL_STMT_LOOP, PLPGSQL_STMT_FORI, PLPGSQL_STMT_DYNFOR, etc. under the hood.

-- Exception blocks create “try-catch” frames: each EXCEPTION clause becomes a handler list keyed by SQLSTATE.

-- Cursor declarations become PLPGSQL_STMT_OPEN, PLPGSQL_STMT_FETCH, PLPGSQL_STMT_CLOSE opcodes.

-- Memory Contexts & Execution Frames:

-- Function Frame: On each call, PostgreSQL allocates a “function context” which holds:

-- Input (IN) parameters (read-only slots).

-- Output (OUT/INOUT) slots.

-- Local variables (declared in DECLARE).

-- A stack of exception frames for nested BEGIN … EXCEPTION … END blocks.

-- Nested Blocks: Entering an IF, LOOP, or sub-BEGIN can create a sub-context for local variables declared inside that block. When that block ends, its sub-context is freed.

-- Branching & Jumping:

-- When the interpreter encounters an IF, it evaluates the condition, then jumps to a specific opcode address if true, or the next test if false.

-- For CASE, it sequences through test opcodes until one condition matches; then it jumps to that branch’s body.

-- For loops, it maintains an index or iterator pointer, evaluates the “exit condition” on each iteration, and jump to the loop’s start or exit label as needed.

-- Exception Dispatching:

-- If a runtime error occurs (e.g., division_by_zero, unique_violation), PL/pgSQL checks the current exception frame list to find a matching handler by SQLSTATE.

-- If found, it unwinds the execution stack back to that BEGIN … EXCEPTION block, free sub-contexts created after that block, and jumps to the handler’s code.

-- If no handler matches, the exception propagates to the caller (which could be the client or another PL/pgSQL function).

-- Cursor State:

-- An explicit cursor has a kernel-level descriptor that holds the result set, a pointer to the current row, and attributes like scrollability.

-- Each FETCH moves that pointer; FOUND is set to TRUE or FALSE accordingly.

-- Closing the cursor frees server-side resources (disk or memory) used to hold the result set.

-- Loop & Exception Combined:

-- Create a function that divides 100 by each element in an input integer array, catching division-by-zero errors.


CREATE OR REPLACE FUNCTION divide_array(arr INT[])
  RETURNS TABLE (input_val INT, result_val NUMERIC, error_text TEXT)
  LANGUAGE plpgsql AS $$
DECLARE
  val INT;
  idx INT;
BEGIN
  FOREACH val IN ARRAY arr LOOP
    BEGIN
      result_val := 100.0 / val;
      error_text := NULL;
    EXCEPTION
      WHEN division_by_zero THEN
        result_val := NULL;
        error_text := 'Division by zero';
    END;
    input_val := val;
    RETURN NEXT;  -- Emit a row into the result set
  END LOOP;
END;
$$;

SELECT * FROM divide_array(ARRAY[25, 0, 5, 0]);
--  input_val | result_val |    error_text
-- -----------+------------+---------------------
--         25 |         4. | NULL
--          0 |       NULL | Division by zero
--          5 |        20. | NULL
--          0 |       NULL | Division by zero

-- Explicit Cursor with FETCH … INTO and EXIT WHEN NOT FOUND

-- Write a function that loops through all tables in a given schema and counts rows in each table.

CREATE OR REPLACE FUNCTION count_rows_in_schema(schema_name TEXT)
  RETURNS TABLE (table_name TEXT, row_count BIGINT)
  LANGUAGE plpgsql AS $$
DECLARE
  cur        REFCURSOR;
  tbl        RECORD;
  count_sql  TEXT;
  cnt        BIGINT;
BEGIN
  OPEN cur FOR
    SELECT tablename
      FROM pg_tables
     WHERE schemaname = schema_name;

  LOOP
    FETCH cur INTO tbl;
    EXIT WHEN NOT FOUND;

    -- Build a dynamic SQL string to count rows
    count_sql := FORMAT(
      'SELECT COUNT(*) FROM %I.%I',
      schema_name, tbl.tablename
    );

    EXECUTE count_sql INTO cnt;
    table_name := tbl.tablename;
    row_count  := cnt;
    RETURN NEXT;
  END LOOP;

  CLOSE cur;
END;
$$;

SELECT * FROM count_rows_in_schema('public');
-- For each table in public, you’ll see its name and row count.

-- Branching and Looping:
-- PL/pgSQL’s IF, CASE, and loops compile into interpreter opcodes that manage jumps and counters.
-- Nested blocks allow variable shadowing and early deallocation of locals.

-- Exception Handling:

-- You define EXCEPTION blocks to catch specific SQLSTATE errors.

-- The interpreter maintains exception frames and unwinds memory contexts when an error is caught.

-- Cursors:
-- Implicit FOR … IN SELECT cursors let you iterate result sets without manual OPEN/FETCH/CLOSE.
-- Explicit cursors give fine-grained control (scrolling, batching, sub-transaction commits).
-- Each cursor holds state on the server, and FOUND indicates whether the last FETCH succeeded.

-- Under-the-Hood Mechanics:

-- The parser builds an AST with nodes for each control construct.
-- During the first call, PL/pgSQL turns that AST into a sequence of opcodes (a plan) stored in memory.

--  On subsequent calls, the cached plan is reused, so loops and branches don’t need to be recompiled.
