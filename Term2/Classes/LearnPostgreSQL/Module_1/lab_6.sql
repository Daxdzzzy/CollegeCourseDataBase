-- Granting Schema-Level Privileges

-- 1. Understand Default "public" Schema 

-- Every new database has a "public" schema. By default, the owner (database owner) has ALL privileges, but other roles have none. 

-- Login in as "postgres" -> Grant USAGE on "public" to "developer"
\c proj_db postgres
GRANT USAGE ON SCHEMA public  TO developer;

-- Without USAGE, members of "developer" cannot reference objects (tables, etc.) in public.

-- Verify 
\dn+ public

-- Access privileges column should show developer=U/postgres

-- 2. Grant CREATE ON "public" to "developer"
GRANT CREATE ON SCHEMA public TO developer;

-- Allows developer role to create tables and other object in [public] schema

-- 3. Test as "dev_bob". (we need to switch role). Try to list tables (initially none). Try creating a table in "public"
\c -dev_bob proj_db
\dt public.*

CREATE TABLE public.todo (
  id SERIAL PRIMARY KEY,
  item TEXT NOT NULL
);

-- Should succeed if schema privileges are correct. 

-- 4. Inspect ACL on the new table
\dp public.todo

-- You should see something like: Schema -> public, Name -> todo, Type -> table, Acces Pivileges -> bob=arwdDxt/bob, developer=arwdDxt/bob, Column Privileges, Policies

-- By defualt, the owner (dev_bob in this case) has ALL privileges  (arwdDxt: INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER).

-- Because bob is a member of [developer], you will also see the developer=arwdDxt/bob entry.


