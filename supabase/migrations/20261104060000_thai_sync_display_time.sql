-- Display-only Bangkok wall time for the Supabase Table Editor.
-- updated_at stays timestamptz and remains the source of truth for sync.
-- Generated columns cannot drift or be overwritten by a client.
begin;

alter table public.chat_records
  add column if not exists updated_at_th timestamp without time zone
  generated always as (updated_at at time zone 'Asia/Bangkok') stored;

alter table public.sos_records
  add column if not exists updated_at_th timestamp without time zone
  generated always as (updated_at at time zone 'Asia/Bangkok') stored;

comment on column public.chat_records.updated_at_th is
  'Display only: updated_at in Asia/Bangkok (UTC+7). Use updated_at for sync and comparisons.';
comment on column public.sos_records.updated_at_th is
  'Display only: updated_at in Asia/Bangkok (UTC+7). Use updated_at for sync and comparisons.';

commit;
