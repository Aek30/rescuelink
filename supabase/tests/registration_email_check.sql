begin;
insert into auth.users(id, email) values
  ('00000000-0000-4000-8000-000000000099', 'registration-check@example.invalid');
set local role anon;
do $$ begin
  assert public.registration_email_exists(' Registration-Check@Example.invalid ');
  assert not public.registration_email_exists('not-registered@example.invalid');
  begin
    perform public.registration_email_exists('invalid');
    raise exception 'Invalid email was accepted';
  exception when others then
    if sqlerrm <> 'Invalid email' then raise; end if;
  end;
  begin
    perform email from auth.users limit 1;
    raise exception 'Anonymous user can read auth.users';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;
