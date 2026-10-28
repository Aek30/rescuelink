-- Preserve complete conversations and explicit owner-side identities.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
do $guard$ begin if regexp_replace((select prosrc from pg_proc where oid='sync_private.apply_chat(uuid,uuid,bigint,jsonb,boolean)'::regprocedure), '\s', '', 'g') <> regexp_replace($expected$
declare
  owner uuid := auth.uid();
  current_row public.chat_records;
  receipt sync_private.chat_receipts;
  request_body jsonb := jsonb_build_object('id',record_id,'base',base_version,'body',body,'deleted',remove_record);
  result jsonb;
begin
  if owner is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if operation is null or record_id is null or base_version is null or base_version < 0 or remove_record is null then
    raise exception 'Invalid operation' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(owner::text || operation::text, 0));
  select * into receipt from sync_private.chat_receipts where owner_id = owner and operation_id = operation;
  if found then
    if receipt.request <> request_body then raise exception 'Operation ID reused' using errcode = '22023'; end if;
    return receipt.response;
  end if;
    if not coalesce(jsonb_typeof(body) = 'object'
    and body->>'id' = record_id::text and body->>'type' = 'message'
    and jsonb_typeof(body->'text') = 'string' and octet_length(body->>'text') <= 24576
    and length(body->>'senderId') between 1 and 100
    and length(body->>'receiverId') between 1 and 100
    and length(body->>'senderName') <= 100
    and body->>'status' in ('pending','sent','delivered','synced')
    and jsonb_typeof(body->'timestamp') = 'string', false)
    then raise exception 'Invalid chat payload' using errcode = '22023'; end if;
  perform (body->>'timestamp')::timestamptz;
perform pg_advisory_xact_lock(hashtextextended(owner::text || record_id::text, 1));
  select * into current_row from public.chat_records where owner_id = owner and id = record_id for update;
  if (current_row.id is null and base_version <> 0)
    or (current_row.id is not null and (current_row.version <> base_version or current_row.deleted)) then
    return jsonb_build_object('outcome','conflict','record',case when current_row.id is null then null else to_jsonb(current_row) end);
  end if;
  insert into public.chat_records(owner_id,id,payload,version,deleted)
    values(owner,record_id,body,base_version+1,remove_record)
    on conflict(owner_id,id) do update set payload=excluded.payload,version=excluded.version,deleted=excluded.deleted,updated_at=now()
    returning * into current_row;
  result := jsonb_build_object('outcome','applied','record',to_jsonb(current_row));
  insert into sync_private.chat_receipts values(owner,operation,request_body,result);
  return result;
end;
$expected$, '\s', '', 'g') then raise exception 'Existing function changed; migration stopped'; end if; end $guard$;

create or replace function sync_private.apply_chat(
  operation uuid, record_id uuid, base_version bigint, body jsonb, remove_record boolean
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  owner uuid := auth.uid();
  current_row public.chat_records;
  receipt sync_private.chat_receipts;
  request_body jsonb := jsonb_build_object('id',record_id,'base',base_version,'body',body,'deleted',remove_record);
  result jsonb;
begin
  if owner is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if operation is null or record_id is null or base_version is null or base_version < 0 or remove_record is null then
    raise exception 'Invalid operation' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(owner::text || operation::text, 0));
  select * into receipt from sync_private.chat_receipts where owner_id = owner and operation_id = operation;
  if found then
    if receipt.request <> request_body then raise exception 'Operation ID reused' using errcode = '22023'; end if;
    return receipt.response;
  end if;
    if not coalesce(jsonb_typeof(body) = 'object'
    and body->>'id' = record_id::text and body->>'type' in ('message','media','sos')
    and jsonb_typeof(body->'text') = 'string' and octet_length(body->>'text') <= 24576
    and length(body->>'senderId') between 1 and 100
    and length(body->>'receiverId') between 1 and 100
    and length(body->>'senderName') <= 100
    and (not (body ? 'archiveIdentity') or body->>'archiveIdentity' in (body->>'senderId', body->>'receiverId'))
    and body->>'status' in ('pending','sent','delivered','synced')
    and jsonb_typeof(body->'timestamp') = 'string', false)
    then raise exception 'Invalid chat payload' using errcode = '22023'; end if;
  perform (body->>'timestamp')::timestamptz;
perform pg_advisory_xact_lock(hashtextextended(owner::text || record_id::text, 1));
  select * into current_row from public.chat_records where owner_id = owner and id = record_id for update;
  if (current_row.id is null and base_version <> 0)
    or (current_row.id is not null and (current_row.version <> base_version or current_row.deleted)) then
    return jsonb_build_object('outcome','conflict','record',case when current_row.id is null then null else to_jsonb(current_row) end);
  end if;
  insert into public.chat_records(owner_id,id,payload,version,deleted)
    values(owner,record_id,body,base_version+1,remove_record)
    on conflict(owner_id,id) do update set payload=excluded.payload,version=excluded.version,deleted=excluded.deleted,updated_at=now()
    returning * into current_row;
  result := jsonb_build_object('outcome','applied','record',to_jsonb(current_row));
  insert into sync_private.chat_receipts values(owner,operation,request_body,result);
  return result;
end;
$$;
commit;

select position('''media'',''sos''' in prosrc)>0 as media_sos_enabled, position('archiveIdentity' in prosrc)>0 as owner_identity_enabled, prosecdef as security_definer, has_function_privilege('authenticated','public.sync_chat(uuid,uuid,bigint,jsonb,boolean)','execute') as authenticated_rpc, has_function_privilege('anon','public.sync_chat(uuid,uuid,bigint,jsonb,boolean)','execute') as anonymous_rpc from pg_proc where oid='sync_private.apply_chat(uuid,uuid,bigint,jsonb,boolean)'::regprocedure;