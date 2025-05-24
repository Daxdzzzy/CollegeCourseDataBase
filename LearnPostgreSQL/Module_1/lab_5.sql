-- Granting Database-Level Privileges 

-- 1. Create a new database "proj_db"
CREATE DATABASE proj_db OWNER postgres;

-- 2. As 'postgres' (superuser), Grant CONNECT on "proj_db" to "developer"
GRANT CONNECT ON DATABASE proj_db TO developer;

-- Verify
\c proj_db
\l + proj_db

-- The [Access privileges] column for [proj_db] should now something like: [developer=CTc/postgres] (CONNECT/TEMPORARY/CRATE)

-- Database ACLs are stored in [pg_data_base.datacl]

-- Granting CONNECT allows any member of [developer] to connect and, if also granted CREATE, create schemas/objects.

-- 3. Grant "CREATE" on Database
GRANT CREATE ON DATABASE proj_db TO developer;

-- This allows developer roles to create schemas inside [proj_db]

-- 4. Test Privileges as "dev_david". (we connect as a superuser, we need to switch role) 
\c - dev_david proj_db
\dn --list schemas (should see only "public" by default)
CREATE SCHEMA dev_schema;

-- If it succeeds, the database and schema privileges are correct.

-- Practically, if [dev_david] can't CONNECT or CREATE, we'd have to check ALCs or parent roles.
