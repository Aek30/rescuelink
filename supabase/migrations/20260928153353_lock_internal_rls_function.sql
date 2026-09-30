-- This is an event trigger, never a public RPC. Keep automatic RLS enabled.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
