-- Two authenticated identities, no retained fixtures.
begin;
insert into auth.users(id) values
 ('61111111-1111-4111-8111-111111111111'),
 ('62222222-2222-4222-8222-222222222222');
set local role authenticated;
select set_config('request.jwt.claim.sub','61111111-1111-4111-8111-111111111111',true);
do $$
declare
  op uuid := gen_random_uuid();
  rid uuid := '63333333-3333-4333-8333-333333333333';
  body jsonb := jsonb_build_object('version',1,'incidentId',rid,'revision',1,'active',true,'name','Phase 3 test','people',1,'category','medical','details','fixture','updatedAt',now(),'location',null);
  first_result jsonb;
  result jsonb;
begin
  first_result := public.sync_sos(op,rid,0,body,false);
  if first_result->>'outcome' <> 'applied' then raise exception 'Create failed'; end if;
  result := public.sync_sos(op,rid,0,body,false);
  if result <> first_result then raise exception 'Replay differs'; end if;
  if (select version from public.sos_records where id=rid) <> 1 then raise exception 'Replay incremented revision'; end if;
  begin
    perform public.sync_sos(op,rid,0,body || '{"details":"different"}',false);
    raise exception 'Reused operation accepted';
  exception when invalid_parameter_value then null; end;
  result := public.sync_sos(gen_random_uuid(),rid,0,body,false);
  if result->>'outcome' <> 'conflict' then raise exception 'Conflict missed'; end if;
  begin
    perform public.sync_sos(gen_random_uuid(),rid,1,body,true);
    raise exception 'Active delete accepted';
  exception when invalid_parameter_value then null; end;
  body := body || '{"active":false,"revision":2}';
  perform public.sync_sos(gen_random_uuid(),rid,1,body,false);
  perform public.sync_sos(gen_random_uuid(),rid,2,body,true);
  result := public.sync_sos(gen_random_uuid(),rid,3,body,false);
  if result->>'outcome' <> 'conflict' then raise exception 'Deleted row resurrected'; end if;
  begin
    update public.sos_records set version=999 where id=rid;
    raise exception 'Direct mutation bypassed RPC';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','62222222-2222-4222-8222-222222222222',true);
do $$
declare result jsonb;
begin
  if exists(select 1 from public.sos_records where owner_id='61111111-1111-4111-8111-111111111111') then raise exception 'B read A'; end if;
  result := public.sync_sos(gen_random_uuid(),'63333333-3333-4333-8333-333333333333',3,
    '{"version":1,"incidentId":"63333333-3333-4333-8333-333333333333","revision":4,"active":false,"name":"B","people":1,"category":"other","details":"B","updatedAt":"2026-09-29T00:00:00Z"}',false);
  if result->>'outcome' <> 'conflict' or result->'record' <> 'null'::jsonb then raise exception 'B touched A or leaked snapshot'; end if;
  begin
    delete from public.sos_records where owner_id='61111111-1111-4111-8111-111111111111';
    raise exception 'B direct delete allowed';
  exception when insufficient_privilege then null; end;
end $$;
set local role anon;
do $$ begin
  begin
    perform public.sync_sos(gen_random_uuid(),gen_random_uuid(),0,'{}',false);
    raise exception 'Anonymous RPC allowed';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
