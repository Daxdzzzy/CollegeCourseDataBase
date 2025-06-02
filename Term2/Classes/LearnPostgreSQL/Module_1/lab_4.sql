-- Creating Roles & Users from Scratch

-- 1. Connect as Superuser

sudo -u postgres psql 

-- 2. Create a "developer" role (NO LOGIN)

CREATE ROLE developer NOLOGIN;

-- This role will group together privileges for all developers; developers themselves will be users who inherit from this

-- Verify
SELECT rolname, rolcanlogin FROM pg_roles
WHERE rolname = 'developer';

-- 3. Create two users: 'dev_david' and 'dev_bov'

CREATE ROLE dev_david LOGIN PASSWORD 'davidPwd123';
CREATE ROLE dev_bob LOGIN PASSWORD 'bobPwd123';

-- These are actual login roles who will become members of [developer]

-- Verify 

SELECT rolname, rolcanlogin FROM pg_roles
WHERE rolname LIKE 'dev_%';

-- 4. Grant Membership: add users to 'developer'

GRANT developer TO dev_david;
GRANT developer TO dev_bob;

-- Now both dev_david and dev_bob automatically inherit whatever privileges we assign to developer.

-- Verify Membership

SELECT rolname,-- 4. Grant Membership: add users to 'developer'

GRANT developer TO dev_david;
GRANT developer TO dev_bob;

-- Now both dev_david and dev_bob automatically inherit whatever privileges we assign to developer.

-- Verify Membership

SELECT rolname,-- 4. Grant Membership: add users to 'developer'

GRANT developer TO dev_david;
GRANT developer TO dev_bob;

-- Now both dev_david and dev_bob automatically inherit whatever privileges we assign to developer.

-- Verify Membership

SELECT roleid::regrole AS parent, member::regrole AS child
FROM pg_auth_members
WHERE roleid = 'developer'::regrole;
