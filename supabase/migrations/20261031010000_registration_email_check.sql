-- Exact-email lookup for the registration form. No user records or identifiers
-- are returned. Apply only when enabling this explicit account-existence UX.
begin;
create schema if not exists registration_private;
revoke all on schema registration_private from public, anon, authenticated;
create table if not exists registration_private.email_check_limits (
  bucket timestamptz not null,
  scope text not null,
  attempts integer not null,
  primary key (bucket, scope)
);
revoke all on registration_private.email_check_limits from public, anon, authenticated;

create or replace function public.registration_email_exists(p_email text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  normalized text := lower(btrim(p_email));
  current_bucket timestamptz := date_trunc('minute', clock_timestamp());
  total integer;
  per_email integer;
begin
  if normalized is null or length(normalized) > 254 or
     normalized !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Invalid email';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(731031001);
  select attempts into total from registration_private.email_check_limits
    where bucket = current_bucket and scope = 'project';
  select attempts into per_email from registration_private.email_check_limits
    where bucket = current_bucket and scope = 'email:' || pg_catalog.md5(normalized);
  if coalesce(total, 0) >= 60 or coalesce(per_email, 0) >= 5 then
    raise sqlstate 'P0001' using message = 'email_check_rate_limited';
  end if;
  insert into registration_private.email_check_limits(bucket, scope, attempts)
    values (current_bucket, 'project', 1),
           (current_bucket, 'email:' || pg_catalog.md5(normalized), 1)
    on conflict (bucket, scope) do update
      set attempts = registration_private.email_check_limits.attempts + 1;
  delete from registration_private.email_check_limits
    where bucket < current_bucket - interval '1 day';
  return exists(select 1 from auth.users
    where lower(email) = normalized and deleted_at is null);
end;
$$;
revoke all on function public.registration_email_exists(text) from public;
grant execute on function public.registration_email_exists(text) to anon, authenticated;
commit;
