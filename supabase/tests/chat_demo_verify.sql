-- Read-only demo evidence. Send a NEW message with this exact text from the app,
-- sign in and sync, then run this in the matching project's SQL Editor.
-- Change the marker for each demo so an old row cannot be mistaken for a new sync.
select
  owner_id,
  id as message_id,
  payload ->> 'text' as message_text,
  payload ->> 'type' as message_type,
  version,
  deleted,
  updated_at as updated_at_utc,
  updated_at at time zone 'Asia/Bangkok' as updated_at_th
from public.chat_records
where payload ->> 'text' = 'DEMO-SYNC-20261104-001'
  and deleted = false
order by updated_at desc;
