-- Role Hierarchies & Inheritance Nuances

-- 1. Create a parent role 'team_lead" with both read & write
CREATE ROLE team_lead NOLOGIN;
GRANT CONNECT ON DATABASE proj_db TO team_lead;
GRANT USAGE, CREATE ON SCHEMA public TO team_lead;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES SCHEMA public TO team_lead;

-- We're setting up a "lead" role that has broader privileges than "readonly", combining both read/write

-- This role can be granted to individual users who need broader access. 

-- 2. Create a "junior" role that only inherits SELECT 

CREATE ROLE junior NOLOGIN INHERIT;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO junior;

-- INHERIT is the default. If we had used  NOINHERIT, membership in a parent role would not automatically give privileges you'd have to explicitly SET ROlE

-- 3. Make "dev_bob" member of "team_lead" and "junior"

GRANT team_lead TO dev_bob;
GRANT junior TO dev_bob;

-- Verify Effective Grants as "dev_bob":
\c - dev_bob proj_db
-- Try to UPDATE a row in public.todo (should work)
UPDATE public.todo SET item='Updated' WHERE id=1;
-- Try to INSERT (should also work, because team_lead has INSERT)
INSERT INTO public.todo(item) VALUES ('Bob writes');
-- Try to DROP TABLE (should fail-no DROP privilege)
DROP TABLE public.todo;

-- dev_bob inherits privileges from both team_lead (read/write) and junior  (read)

-- demonstrates how multiple role memberships combine.

-- 4. Prefix Checking vs Inheritance 

-- Example: If we had created junior NOINHERIT, then even though dev_bob is a member of junior, he wuould not see SELECT by default; he'd have to run SET ROLE junior; SELECT .... ; RESET ROLE;

-- This nuance matters when you want a role that's only used for occasional escalations rather than permanent privilege inheritance.
