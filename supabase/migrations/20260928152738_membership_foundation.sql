-- Phase 2 membership foundation. Apply once in Supabase SQL Editor.
begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 100),
  created_at timestamptz not null default now()
);

-- Installation IDs are random app-install IDs, never hardware identifiers.
-- One account may use many installations; a shared installation may be linked
-- to multiple accounts. This link does not grant access to another owner.
create table public.account_devices (
  user_id uuid not null references public.profiles(id) on delete cascade,
  installation_id uuid not null,
  radio_identity uuid not null,
  linked_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (user_id, installation_id)
);

-- Future cloud-sync envelope. SOS and chat never wait for this table.
-- No automatic upload of local history is implemented in this phase.
create table public.owned_records (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  id uuid not null,
  installation_id uuid not null,
  kind text not null check (kind in ('message', 'sos')),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  revision bigint not null default 1 check (revision > 0),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (owner_id, id),
  foreign key (owner_id, installation_id)
    references public.account_devices(user_id, installation_id)
);
create index owned_records_device on public.owned_records(owner_id, installation_id);

alter table public.profiles enable row level security;
alter table public.account_devices enable row level security;
alter table public.owned_records enable row level security;

revoke all on public.profiles, public.account_devices, public.owned_records from anon;
grant select, insert, update, delete on public.profiles, public.account_devices, public.owned_records to authenticated;

create policy profiles_owner on public.profiles for all to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy devices_owner on public.account_devices for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy records_owner on public.owned_records for all to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);

-- Fixed search_path; no client-supplied role or privileged profile fields.
create function private.create_member_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id) values (new.id);
  return new;
end;
$$;
revoke all on function private.create_member_profile() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
for each row execute function private.create_member_profile();

commit;
