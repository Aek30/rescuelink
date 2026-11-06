-- Read-only comparison for the actual text messages inspected on the phone.
-- Run in the RescueLink Supabase SQL Editor. No data is changed.
with phone_messages (id, expected_text) as (
  values
    ('89cb6294-a4f1-4f06-a580-4162a15b641c'::uuid, 'hi'),
    ('2e112171-57da-46a7-ba36-c5565c5fa04c'::uuid, 'are you here'),
    ('117af846-4194-4ff2-b473-eb3dd63abde9'::uuid, 'hi'),
    ('9b682e8f-7f11-4813-b22c-a5f437f40058'::uuid, 'hi')
)
select
  p.id as phone_message_id,
  p.expected_text,
  c.payload ->> 'text' as cloud_text,
  case
    when c.id is null then 'NOT_FOUND'
    when c.deleted then 'DELETED'
    when c.payload ->> 'text' is distinct from p.expected_text then 'TEXT_DIFFERS'
    else 'MATCH'
  end as verification,
  c.version,
  c.updated_at at time zone 'Asia/Bangkok' as updated_at_th
from phone_messages p
left join public.chat_records c
  on c.id = p.id
  and c.owner_id = 'ab2d595f-87a1-4bda-a25c-ab4b47397d76'::uuid
order by c.updated_at desc nulls last;
