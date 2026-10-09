-- Synthetic users only, all changes roll back. No email is sent.
begin;
insert into auth.users(id, raw_user_meta_data) values
 ('91111111-1111-4111-8111-111111111111', '{"display_name":"Existing A","full_name":"Test A","terms_version":"2026-10-09"}'),
 ('92222222-2222-4222-8222-222222222222', '{"display_name":"Existing B"}');
set local role authenticated;
select set_config('request.jwt.claim.sub','91111111-1111-4111-8111-111111111111',true);
select public.save_rescue_profile('{"display_name":"A","full_name":"Test A","phone":"0812345678","date_of_birth":"2000-01-01","terms_version":"2026-10-09","health_consent":true,"blood_group":"O","rh_factor":"ไม่ทราบ","allergies":"Test only","emergency_contact_name":"Test contact"}');
do $$ begin
 if (select count(*) from public.emergency_medical_profiles) <> 1 then raise exception 'Owner save failed'; end if;
 if (select allergies from public.emergency_medical_profiles) <> 'Test only' then raise exception 'Medical save failed'; end if;
 if (select phone from public.profiles) <> '0812345678' then raise exception 'Personal save failed'; end if;
 begin
   update public.emergency_medical_profiles set health_consent=false;
   raise exception 'Medical data without consent accepted';
 exception when check_violation then null; end;
end $$;
select set_config('request.jwt.claim.sub','92222222-2222-4222-8222-222222222222',true);
do $$ declare affected integer; begin
 if exists(select 1 from public.emergency_medical_profiles) then raise exception 'B can read A health'; end if;
 update public.emergency_medical_profiles set allergies='tampered';
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'B can update A'; end if;
 delete from public.emergency_medical_profiles;
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'B can delete A'; end if;
 begin
   insert into public.emergency_medical_profiles(id,health_consent,consent_at,allergies)
   values('91111111-1111-4111-8111-111111111111',true,now(),'tampered');
   raise exception 'B can insert A';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','91111111-1111-4111-8111-111111111111',true);
select public.save_rescue_profile('{"display_name":"A","full_name":"Test A","phone":"0812345678","date_of_birth":"2000-01-01","terms_version":"2026-10-09","health_consent":false}');
do $$ begin
 if exists(select 1 from public.emergency_medical_profiles) then raise exception 'Withdrawal did not delete health'; end if;
 if (select full_name from public.profiles) <> 'Test A' then raise exception 'Withdrawal damaged account'; end if;
end $$;
set local role anon;
do $$ begin
 begin
   perform 1 from public.emergency_medical_profiles;
   raise exception 'Anonymous health access allowed';
 exception when insufficient_privilege then null; end;
 begin
   perform public.save_rescue_profile('{}');
   raise exception 'Anonymous RPC allowed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'PASS: owner save, consent enforcement, cross-account RLS, health deletion, anonymous denial' as verification;
rollback;
