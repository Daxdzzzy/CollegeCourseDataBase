-- 1. Row Level Security (RLS) Bassics

-- RLS policies are stored in [pg_policies]

-- The engine checks these policies after ACL checks and before returning rows.

-- We won't dive deeper in this session, but in production you may layer table ACLs with RLS to get fine-grained row filtering. : ((( >:(((( ;(

-- Enable RLS on a table (requires beign table owner)
ALTER TABLE public.test_default ENABLE ROW LEVEL SECURITY;

-- Create a policy that only allows users to SELECT rows where created_by = current_user
Create POLICY user_only_select
  ON public.test_default
  FOR SELECT
  USING (created_by = current_user);


