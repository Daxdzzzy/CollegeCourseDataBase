-- 1. User vs Roles.

-- Internally, PostgreSQL has a single namespace for "roles".

-- roles can own objects and hold privileges; a role becomes a "user" by granting it LOGIN.

-- This is unified model simplifies inheritance: any role can be a member of another role, wheter or not it has login.

-- Create a role that can't login (generic role)
CREATE ROLE analyst NOLOGIN;

-- Create a user (role with LOGIN)
CREATE ROLE david LOGIN PASSWORD 'secure';

-- 2. System Catalog & Permission Storage

-- [pg_roles] is a publicly visible view over [pg_authid], which stores encrypted passwords and role attributes.

-- Privileges on object (databases, schemas, tables) are stored in ACL (Access Control Lists) columns of catalog tables (e.g., [pg_database.datacl], [pg_class.relacl] )

-- Whenever you run GRANT or REVOKE, PostrgreSQL modifies these ACL arrays to reflect allowed/denied permissions.

-- List all roles visible in the cluster.
SELECT rolname, rolsuper, rolecreaterole, rolecreatedatabase, rolcanlogin
FROM pg_roles
  ORDER BY rolname;

-- 3. Privelege Types & Hierarchy

-- Separting privileges by object type enforces the principle of least privilege: roles only get exactly the rights they need at the appropiate granularity.

-- Underneath, each object's ACL is an array of entries of form [rolename=privileges/grantor].

-- Database-level vs Schema-level vs Table-level

-- Database: CONNECT, CREATE, TEMPORARY

-- SCHEMA: USAGE, CREATE.

-- TABLE (or other objects): SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER

