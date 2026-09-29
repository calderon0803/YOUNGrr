-- Uploads only as <your id>/<random name>.jpg: no other folders, names or
-- extensions (defence in depth on top of the JPEG-only buckets). Files are
-- never overwritten: the avatar "update" permission goes away (the app always
-- uploads a new file and deletes the old one).

drop policy if exists "upload own photos" on storage.objects;
create policy "upload own photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and name ~ ('^' || auth.uid()::text || '/[A-Za-z0-9_-]{1,64}\.jpg$'));

drop policy if exists "upload own avatar and cover" on storage.objects;
create policy "upload own avatar" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and name ~ ('^' || auth.uid()::text || '/[A-Za-z0-9_-]{1,64}\.jpg$'));
drop policy if exists "replace own avatar and cover" on storage.objects;

drop policy if exists "upload own cover" on storage.objects;
create policy "upload own cover" on storage.objects for insert to authenticated
  with check (bucket_id = 'covers' and name ~ ('^' || auth.uid()::text || '/[A-Za-z0-9_-]{1,64}\.jpg$'));
