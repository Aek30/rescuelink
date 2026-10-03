begin;
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('chat-media', 'chat-media', false, 52428800,
 array['image/jpeg','image/png','image/gif','image/webp','image/heic','video/mp4','video/quicktime','video/x-msvideo','video/x-matroska','video/webm','video/3gpp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
create policy chat_media_insert on storage.objects for insert to authenticated
with check (bucket_id = 'chat-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy chat_media_select on storage.objects for select to authenticated
using (bucket_id = 'chat-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy chat_media_update on storage.objects for update to authenticated
using (bucket_id = 'chat-media' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'chat-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy chat_media_delete on storage.objects for delete to authenticated
using (bucket_id = 'chat-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
create table public.media_records (
 owner_id uuid not null references public.profiles(id) on delete cascade,
 id uuid not null, message_id uuid not null,
 file_name text not null check (char_length(file_name) between 1 and 255),
 mime_type text not null check (mime_type like 'image/%' or mime_type like 'video/%'),
 file_size bigint not null check (file_size between 1 and 52428800),
 checksum text not null check (checksum ~ '^[a-f0-9]{64}$'),
 created_at timestamptz not null,
 primary key(owner_id, id)
);
alter table public.media_records enable row level security;
revoke all on public.media_records from anon;
grant select, insert, update, delete on public.media_records to authenticated;
create policy media_records_owner on public.media_records for all to authenticated
using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
commit;
