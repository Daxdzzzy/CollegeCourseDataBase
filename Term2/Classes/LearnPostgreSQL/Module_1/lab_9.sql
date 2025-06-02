-- Revoking Privileges & Cleaning Up 

-- 1. Revoke specific privilege from a role. ( Remove INSERT from team_lead on public.todo)
REVOKE INSERT ON public.todo FROM team_lead;

-- This updates the ACL array in pg_class for public.todo, removing the I flag from the entry for team_lead.

-- Now any member of team_lead cannot INSERT into public.todo (unless they have another direct grant).

-- 2. Revoke inherited privelege (Suppose we no longer want dev_bob to inherit team_lead privileges).
REVOKE team_lead FROM dev_bob;

-- Verify
\c - dev_bob proj_db
INSERT INTO public.todo(item) VALUES('should fail now');

-- Revoking membership automatically removes all privileges inherited from that parent.

-- However, any privileges granted directly to dev_bob would remain. 

-- 3. Revoke all privileges on an object 
REVOKE ALL PRIVILEGES ON public.todo  FROM PUBLIC;

-- IMPORTANT!!! PUBLIC is buil-in role representing all roles, so this removes any default or accidental grants underlying "public"

-- Ensure no unintended broad acces.

-- 4. Dropping roles in clean up (As superuser)
-- First, revoke ALL object privileges from the role
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM junior;
-- Then drop role
DROP ROLE junior;

-- PostgreSQL will refuse to drop a role that still owns objects or has privileges. You must revoke or reassing ownership first. 

-- Ownership lives in pg_class.relowner, pg_database.datdba, etc.
