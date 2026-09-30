-- Run after the migration in SQL Editor. All fixtures roll back.
begin;
insert into auth.users(id) values
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222');

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
insert into public.account_devices(user_id, installation_id, radio_identity)
values ('11111111-1111-4111-8111-111111111111',
        '33333333-3333-4333-8333-333333333333',
        '44444444-4444-4444-8444-444444444444');
insert into public.owned_records(owner_id, id, installation_id, kind, payload)
values ('11111111-1111-4111-8111-111111111111',
        '55555555-5555-4555-8555-555555555555',
        '33333333-3333-4333-8333-333333333333', 'message', '{}');

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
do $$
declare affected integer;
begin
  if (select count(*) from public.profiles) <> 1 then raise exception 'Profile RLS failed'; end if;
  if exists(select 1 from public.account_devices) then raise exception 'Device RLS failed'; end if;
  if exists(select 1 from public.owned_records) then raise exception 'Record RLS failed'; end if;
  update public.owned_records set payload = '{"tampered":true}';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Cross-owner update allowed'; end if;
  delete from public.owned_records;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Cross-owner delete allowed'; end if;
  begin
    insert into public.account_devices(user_id, installation_id, radio_identity)
    values ('11111111-1111-4111-8111-111111111111', gen_random_uuid(), gen_random_uuid());
    raise exception 'Cross-owner insert allowed';
  exception when insufficient_privilege then null;
  end;
end $$;

set local role anon;
do $$ begin
  begin
    perform 1 from public.profiles;
    raise exception 'Anonymous profile access allowed';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;
