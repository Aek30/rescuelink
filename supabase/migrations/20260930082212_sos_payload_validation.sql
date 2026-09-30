-- Timestamp matches the applied remote migration.
alter table public.sos_records add constraint sos_payload_types check (
  coalesce(jsonb_typeof(payload->'version') = 'number'
    and jsonb_typeof(payload->'people') = 'number'
    and jsonb_typeof(payload->'revision') = 'number'
    and (payload->'location' is null or payload->'location' = 'null'::jsonb or (
      jsonb_typeof(payload->'location'->'latitude') = 'number'
      and jsonb_typeof(payload->'location'->'longitude') = 'number'
      and jsonb_typeof(payload->'location'->'accuracy') = 'number'
    )), false)
);
create policy receipts_deny_client on sync_private.sos_receipts
  for all to authenticated using (false) with check (false);
