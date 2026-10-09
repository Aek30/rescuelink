-- Synthetic accounts and records are rolled back after verification.
begin;
insert into auth.users(id) values
 ('71111111-1111-4111-8111-111111111111'),
 ('72222222-2222-4222-8222-222222222222');
set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-1111-4111-8111-111111111111',true);
do $$
declare
 op uuid := gen_random_uuid();
 rid uuid := '73333333-3333-4333-8333-333333333333';
 body jsonb := jsonb_build_object('id',rid,'senderId','sender','senderName','Test','receiverId','receiver','text','offline hello','type','message','status','pending','timestamp',now());
 first_result jsonb;
 result jsonb;
begin
 first_result := public.sync_chat(op,rid,0,body,false);
 if first_result->>'outcome' <> 'applied' then raise exception 'Create failed'; end if;
 if public.sync_chat(op,rid,0,body,false) <> first_result then raise exception 'Replay differs'; end if;
 if (select version from public.chat_records where id=rid) <> 1 then raise exception 'Duplicate upload'; end if;
 begin
   perform public.sync_chat(op,rid,0,body || '{"text":"changed"}',false);
   raise exception 'Reused operation accepted';
 exception when invalid_parameter_value then null; end;
 result := public.sync_chat(gen_random_uuid(),rid,0,body,false);
 if result->>'outcome' <> 'conflict' then raise exception 'Missed conflict'; end if;
 perform public.sync_chat(gen_random_uuid(),rid,1,body || '{"text":"edited"}',false);
 if (select payload->>'text' from public.chat_records where id=rid) <> 'edited' then raise exception 'Edit failed'; end if;
 perform public.sync_chat(gen_random_uuid(),rid,2,body,true);
 if not (select deleted from public.chat_records where id=rid) then raise exception 'Delete failed'; end if;
 result := public.sync_chat(gen_random_uuid(),rid,3,body,false);
 if result->>'outcome' <> 'conflict' then raise exception 'Deleted row resurrected'; end if;
 begin
   update public.chat_records set version=999 where id=rid;
   raise exception 'Direct write bypassed RPC';
 exception when insufficient_privilege then null; end;
 begin
   perform public.sync_chat(gen_random_uuid(),gen_random_uuid(),0,'{}',false);
   raise exception 'Invalid payload accepted';
 exception when invalid_parameter_value then null; end;
end $$;
select set_config('request.jwt.claim.sub','72222222-2222-4222-8222-222222222222',true);
do $$
declare result jsonb;
begin
 if exists(select 1 from public.chat_records where owner_id='71111111-1111-4111-8111-111111111111') then raise exception 'B read A'; end if;
 result := public.sync_chat(gen_random_uuid(),'73333333-3333-4333-8333-333333333333',3,
   '{"id":"73333333-3333-4333-8333-333333333333","senderId":"sender","senderName":"B","receiverId":"receiver","text":"B","type":"message","status":"pending","timestamp":"2026-10-08T00:00:00Z"}',false);
 if result->>'outcome' <> 'conflict' or result->'record' <> 'null'::jsonb then raise exception 'B touched A'; end if;
 begin
   delete from public.chat_records where owner_id='71111111-1111-4111-8111-111111111111';
   raise exception 'Direct delete accepted';
 exception when insufficient_privilege then null; end;
end $$;
set local role anon;
do $$ begin
 begin
   perform public.sync_chat(gen_random_uuid(),gen_random_uuid(),0,'{}',false);
   raise exception 'Anonymous upload allowed';
 exception when insufficient_privilege then null; end;
 begin
   perform 1 from public.chat_records;
   raise exception 'Anonymous read allowed';
 exception when insufficient_privilege then null; end;
end $$;
rollback;
