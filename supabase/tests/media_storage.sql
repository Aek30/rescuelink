begin;
insert into storage.objects(bucket_id, name) values ('chat-media','11111111-1111-4111-8111-111111111111/phase4-policy-test');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
do $$ begin
 if (select count(*) from storage.objects where name='11111111-1111-4111-8111-111111111111/phase4-policy-test') <> 1 then
 raise exception 'Owner cannot read'; end if;
end $$;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}', true);
do $$ declare affected integer; begin
 if exists(select 1 from storage.objects where name='11111111-1111-4111-8111-111111111111/phase4-policy-test') then
 raise exception 'Other account can read'; end if;
 update storage.objects set metadata='{}' where name='11111111-1111-4111-8111-111111111111/phase4-policy-test';
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'Other account can update'; end if;
 begin
 delete from storage.objects where name='11111111-1111-4111-8111-111111111111/phase4-policy-test';
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'Other account can delete'; end if;
 exception when insufficient_privilege then null;
 end;
 begin
 insert into storage.objects(bucket_id,name) values('chat-media','11111111-1111-4111-8111-111111111111/forbidden');
 raise exception 'Other account can insert';
 exception when insufficient_privilege then null;
 end;
end $$;
rollback;
select 'PASS: owner read; other account read/update/delete/insert denied; fixtures rolled back' as result;
