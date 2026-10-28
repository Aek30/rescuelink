rollback;
begin;
select set_config('rescuelink.test_owner',gen_random_uuid()::text,true);
select set_config('rescuelink.test_other',gen_random_uuid()::text,true);
select set_config('rescuelink.test_radio',gen_random_uuid()::text,true);
insert into auth.users(id) values(current_setting('rescuelink.test_owner')::uuid),(current_setting('rescuelink.test_other')::uuid);
insert into public.account_devices(user_id,installation_id,radio_identity) values
(current_setting('rescuelink.test_owner')::uuid,gen_random_uuid(),current_setting('rescuelink.test_radio')::uuid),
(current_setting('rescuelink.test_owner')::uuid,gen_random_uuid(),gen_random_uuid());
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('rescuelink.test_owner'),true);
do $test$
declare kind text; rid uuid; op uuid; payload jsonb; result jsonb; first_result jsonb;
begin
  foreach kind in array array['message','media','sos'] loop
    rid:=gen_random_uuid(); op:=gen_random_uuid();
    payload:=jsonb_build_object('id',rid,'senderId',current_setting('rescuelink.test_radio'),'receiverId','synthetic-peer','senderName','Synthetic owner','text','Synthetic history','type',kind,'status','synced','timestamp',now(),'archiveIdentity',current_setting('rescuelink.test_radio'),'peerName','Existing contact');
    first_result:=public.sync_chat(op,rid,0,payload,false);
    if first_result->>'outcome'<>'applied' then raise exception 'Archive write failed'; end if;
    if public.sync_chat(op,rid,0,payload,false)<>first_result then raise exception 'Idempotency failed'; end if;
    if (select r.payload->>'archiveIdentity' from public.chat_records r where r.id=rid)<>current_setting('rescuelink.test_radio') then raise exception 'Identity lost'; end if;
    perform set_config('rescuelink.test_record',rid::text,true);
  end loop;
  if (select count(*) from public.chat_records)<>3 then raise exception 'Incomplete history'; end if;
  if (select count(*) from public.account_devices)<>2 then raise exception 'Device identities not shared'; end if;
  rid:=gen_random_uuid();
  begin
    perform public.sync_chat(gen_random_uuid(),rid,0,payload||jsonb_build_object('id',rid,'archiveIdentity','unrelated'),false);
    raise exception 'Invalid owner identity accepted';
  exception when invalid_parameter_value then null; end;
end $test$;
select set_config('request.jwt.claim.sub',current_setting('rescuelink.test_other'),true);
do $test$ declare result jsonb; begin
  if exists(select 1 from public.chat_records) then raise exception 'Cross-account history leak'; end if;
  if exists(select 1 from public.account_devices) then raise exception 'Cross-account identity leak'; end if;
  result:=public.sync_chat(gen_random_uuid(),current_setting('rescuelink.test_record')::uuid,1,jsonb_build_object('id',current_setting('rescuelink.test_record'),'senderId','synthetic','receiverId','peer','senderName','Other','text','test','type','message','status','pending','timestamp',now()),false);
  if result->>'outcome'<>'conflict' or result->'record'<>'null'::jsonb then raise exception 'Cross-account write accepted'; end if;
end $test$;
set local role anon;
do $test$ begin
  begin
    perform public.sync_chat(gen_random_uuid(),gen_random_uuid(),0,'{}',false);
    raise exception 'Anonymous write accepted';
  exception when insufficient_privilege then null; end;
end $test$;
rollback;
select true as chat_cloud_checks_passed,true as account_isolation_passed,true as anonymous_blocked,true as temporary_data_rolled_back;