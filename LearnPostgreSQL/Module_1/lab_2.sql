-- 1. Roles Attributes

-- Attributes you will frequently use: 

-- LOGIN:  Can authenticate.

-- SUPERUSER: Bypass all permission checks. 

-- CREATEROLE: Can create, alter,  and drop other roles. 

-- CREATEDB: Can create new databases

-- Attributes live in [pg_authid] (visible via [pg_roles]) 

-- PostgreSQL checks these flags before checking ACLs objects.

-- If a role is [SUPERUSER] it automatically sees and does everything; non-superusers must realy on ACL entries.

-- Create a read-only role without login
CREATE ROLE read_only NOLOGIN;

-- Create a user and give it the ability to create databases
CREATE ROLE dba LOGIN PASSWORD 'db@123' CREATEDB;

-- 2. Role Membership (Inheritance) 

-- Role membership is stored in [pg_auth_members]

-- By default, if role A is a member of role B, A "Inherits" B's privileges. You can disable inheritance with [NOINHERIT], but typically you leave inheritance on so that a "user" role collects privileges from all parent roles.

-- This lets you define a "role hierarchy" (e. g., [analyst -> senior_analyst -> dba] ) rather than granting privileges directly to every user.

-- Grant membership of role read_only to user david
GRANT read_only TO alice;

-- Verify membership 
SELECT pg_has_role('david', 'read_only', 'member') AS is_member;

-- 3. Understanding Default Privileges

-- By default, the role that owns an object (usually the creator) has full rights, and public (all roles) has no rights except CONNECT on database and usage on public schema.

-- Knowing defaults saves you from granting privileges you don't need to explicitly set.

-- Check default ACL on a newly created table (typically owner =rwd DDL)
CREATE TABLE public.test_default (id serial PRIMARY KEY, data text); 
\dp public.test_default
