-- Table-Level Privileges & SELECT/INSERT/UPDATE/DELETE

-- 1. Create a "readonly" role.
\c proj_db postgres
CREATE ROLE readonly NOLOGIN;

-- 2. Grant "SELECT" on ALL existing tables in "public" to "readonly"
GRANT SELECT ON ALL TABLES IN SCHEMA PUBLIC TO readonly;

-- Verify 
\dp public.todo 

-- You should see readonly=r/postgres in the Access privileges column.

-- Granting SELECT on ALL TABLES modifies each table's ACL in [pg_class.relacl] to include the readonly role.

-- Future tables will not automatically grant SELECT to readonly unless we also set default privileges.

-- 3. Create a "reporting" user and make it member of "readonly"
CREATE ROLE report_user LOGIN PASSWORD 'reportPwd!';
GRANT readonly TO report_user;

-- 4. Test as "report_user"
\c - report_user proj_db 
-- Attempt SELECT
SELECT * FROM public.todo;  --should work 
-- Attempt INSERT (should fail)
INSERT INTO public.todo(item) VALUES ('Test');


-- Because "report_user" inherits readonly's SELECT right but has no INSERT right explicitly

-- This demonstrates separation of read vs write privileges.

-- 5. Grant future table privileges automatically. (As the owner of public schema.)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO readonly;

-- This command updates the default ACL for tables created in the future. 

-- Default privileges are stored in [pg_default_acl] and applied whenever a new object is created
