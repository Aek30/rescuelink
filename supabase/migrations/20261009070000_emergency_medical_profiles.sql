-- Migration: Emergency Medical Profiles
-- Adds emergency_medical_profiles table separate from profiles.
-- Applies on top of existing membership_foundation migration.
-- Safe to run: does NOT drop or alter existing data.

begin;

-- ── Extend profiles with display_name if missing ─────────────────────────
-- (profiles already has display_name from foundation migration — skip if present)
alter table public.profiles
  add column if not exists full_name text not null default '' check (char_length(full_name) <= 200),
  add column if not exists phone text not null default '' check (char_length(phone) <= 30),
  add column if not exists date_of_birth date check (date_of_birth <= current_date),
  add column if not exists terms_version text,
  add column if not exists terms_accepted_at timestamptz;

-- ── Emergency Medical Profiles ────────────────────────────────────────────
-- Stored in a separate table so health data can be independently managed,
-- audited, and deleted without affecting authentication or messaging data.

create table if not exists public.emergency_medical_profiles (
  id               uuid primary key references public.profiles(id) on delete cascade,

  -- Blood data (self-reported; disclaimer: not for clinical use)
  blood_group      text check (blood_group in ('A','B','AB','O','ไม่ทราบ')),
  rh_factor        text check (rh_factor in ('Positive (+)','Negative (-)','ไม่ทราบ')),

  -- Medical history (free text, optional)
  medical_conditions text  check (char_length(medical_conditions)  <= 2000),
  allergies          text  check (char_length(allergies)            <= 2000),
  medications        text  check (char_length(medications)          <= 2000),
  medical_notes      text  check (char_length(medical_notes)        <= 2000),

  -- Emergency contact
  emergency_contact_name     text check (char_length(emergency_contact_name)     <= 200),
  emergency_contact_phone    text check (char_length(emergency_contact_phone)    <= 30),
  emergency_contact_relation text check (char_length(emergency_contact_relation) <= 100),

  -- Consent tracking (required to store health data)
  health_consent   boolean not null default false,
  consent_at       timestamptz,

  -- Timestamps
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ── Row-Level Security ────────────────────────────────────────────────────
-- Only the owner may read, insert, update, or delete their health record.
-- No other authenticated user or anon may access it.

alter table public.emergency_medical_profiles enable row level security;

revoke all on public.emergency_medical_profiles from anon, authenticated;
grant select, insert, update, delete
  on public.emergency_medical_profiles to authenticated;

drop policy if exists emp_owner on public.emergency_medical_profiles;
create policy emp_owner on public.emergency_medical_profiles
  for all to authenticated
  using  ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

alter table public.emergency_medical_profiles add constraint emp_consent_required check (
  (health_consent and consent_at is not null) or (
    not health_consent and blood_group is null and rh_factor is null
    and medical_conditions is null and allergies is null and medications is null
    and medical_notes is null and emergency_contact_name is null
    and emergency_contact_phone is null and emergency_contact_relation is null
  )
);

-- ── Auto-update updated_at ────────────────────────────────────────────────
create or replace function private.set_updated_at()
returns trigger language plpgsql security definer
set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function private.set_updated_at() from public, anon, authenticated;

drop trigger if exists emp_updated_at on public.emergency_medical_profiles;
create trigger emp_updated_at
  before update on public.emergency_medical_profiles
  for each row execute function private.set_updated_at();

-- ── Helper: upsert emergency medical profile ─────────────────────────────
-- Called by the app after signup when health_consent = true.
-- Uses RLS: caller must be the authenticated owner.

create or replace function public.upsert_emergency_medical_profile(
  p_blood_group              text  default null,
  p_rh_factor                text  default null,
  p_medical_conditions       text  default null,
  p_allergies                text  default null,
  p_medications              text  default null,
  p_medical_notes            text  default null,
  p_emergency_contact_name   text  default null,
  p_emergency_contact_phone  text  default null,
  p_emergency_contact_relation text default null
) returns void
language plpgsql security invoker
set search_path = ''
as $$
begin
  insert into public.emergency_medical_profiles (
    id, blood_group, rh_factor,
    medical_conditions, allergies, medications, medical_notes,
    emergency_contact_name, emergency_contact_phone, emergency_contact_relation,
    health_consent, consent_at
  ) values (
    auth.uid(), p_blood_group, p_rh_factor,
    p_medical_conditions, p_allergies, p_medications, p_medical_notes,
    p_emergency_contact_name, p_emergency_contact_phone, p_emergency_contact_relation,
    true, now()
  )
  on conflict (id) do update set
    blood_group              = excluded.blood_group,
    rh_factor                = excluded.rh_factor,
    medical_conditions       = excluded.medical_conditions,
    allergies                = excluded.allergies,
    medications              = excluded.medications,
    medical_notes            = excluded.medical_notes,
    emergency_contact_name   = excluded.emergency_contact_name,
    emergency_contact_phone  = excluded.emergency_contact_phone,
    emergency_contact_relation = excluded.emergency_contact_relation,
    health_consent           = true,
    consent_at               = coalesce(
      public.emergency_medical_profiles.consent_at, now()
    );
end;
$$;
-- Revoke from anon; authenticated users call via their own session (RLS enforced).
revoke all on function public.upsert_emergency_medical_profile from public, anon;
grant execute on function public.upsert_emergency_medical_profile to authenticated;

-- ── Helper: withdraw health consent (soft wipe) ───────────────────────────
-- Clears all health data fields and sets health_consent = false.
-- The row itself is kept for audit; hard delete is a separate admin operation.

create or replace function public.withdraw_health_consent()
returns void
language plpgsql security invoker
set search_path = ''
as $$
begin
  update public.emergency_medical_profiles set
    blood_group              = null,
    rh_factor                = null,
    medical_conditions       = null,
    allergies                = null,
    medications              = null,
    medical_notes            = null,
    emergency_contact_name   = null,
    emergency_contact_phone  = null,
    emergency_contact_relation = null,
    health_consent           = false
  where id = auth.uid();
end;
$$;
revoke all on function public.withdraw_health_consent from public, anon;
grant execute on function public.withdraw_health_consent to authenticated;

-- Atomic personal + medical save. Caller identity comes only from auth.uid().
-- Never overwrite other owners or add medical fields to public/radio profiles.
create or replace function public.save_rescue_profile(p_data jsonb)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if jsonb_typeof(p_data) <> 'object' or
     coalesce(char_length(trim(p_data->>'display_name')), 0) = 0 then
    raise exception 'Display name required';
  end if;
  if p_data->>'terms_version' is not null and p_data->>'terms_version' <> '2026-10-09' then
    raise exception 'Invalid policy version';
  end if;
  update public.profiles set
    display_name = trim(p_data->>'display_name'),
    full_name = coalesce(trim(p_data->>'full_name'), ''),
    phone = coalesce(trim(p_data->>'phone'), ''),
    date_of_birth = nullif(p_data->>'date_of_birth', '')::date,
    terms_version = coalesce(p_data->>'terms_version', terms_version),
    terms_accepted_at = case when p_data->>'terms_version' is not null
      then coalesce(terms_accepted_at, now()) else terms_accepted_at end
  where id = auth.uid();
  if not found then raise exception 'Profile missing'; end if;
  if coalesce((p_data->>'health_consent')::boolean, false) then
    if p_data->>'terms_version' <> '2026-10-09' or p_data->>'terms_version' is null then
      raise exception 'Policy consent required';
    end if;
    perform public.upsert_emergency_medical_profile(
      p_data->>'blood_group', p_data->>'rh_factor', p_data->>'medical_conditions',
      p_data->>'allergies', p_data->>'medications', p_data->>'medical_notes',
      p_data->>'emergency_contact_name', p_data->>'emergency_contact_phone',
      p_data->>'emergency_contact_relation'
    );
  else
    -- Withdrawal removes the entire medical row; account/messages are untouched.
    delete from public.emergency_medical_profiles where id = auth.uid();
  end if;
end;
$$;
revoke all on function public.save_rescue_profile(jsonb) from public, anon;
grant execute on function public.save_rescue_profile(jsonb) to authenticated;

-- New accounts get personal fields even when confirmation happens on another
-- device. Existing rows are never backfilled/replaced by this trigger change.
create or replace function private.create_member_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, display_name, full_name, phone, date_of_birth,
    terms_version, terms_accepted_at)
  values (new.id,
    left(coalesce(new.raw_user_meta_data->>'display_name', ''), 100),
    left(coalesce(new.raw_user_meta_data->>'full_name', ''), 200),
    left(coalesce(new.raw_user_meta_data->>'phone', ''), 30),
    case when new.raw_user_meta_data->>'date_of_birth' ~ '^\d{4}-\d{2}-\d{2}$'
      then (new.raw_user_meta_data->>'date_of_birth')::date else null end,
    case when new.raw_user_meta_data->>'terms_version' = '2026-10-09'
      then '2026-10-09' else null end,
    case when new.raw_user_meta_data->>'terms_version' = '2026-10-09'
      then now() else null end);
  return new;
end;
$$;
revoke all on function private.create_member_profile() from public, anon, authenticated;

commit;

-- ── Notes for Supabase dashboard setup ───────────────────────────────────
-- 1. Enable Email Confirmation in Auth > Settings > Email provider.
-- 2. Set minimum password length to 8 in Auth > Settings > Password policy.
-- 3. Ensure "Confirm email" is ON so unverified users cannot sign in.
-- 4. No other roles or service-role policies are needed for this table.
-- 5. The emergency_medical_profiles table is NOT exposed in any public
--    Nearby broadcast or SOS payload — health data stays server-side only.
