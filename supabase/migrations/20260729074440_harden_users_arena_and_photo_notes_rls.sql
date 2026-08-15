drop policy if exists "Public profiles are viewable by authenticated users" on public.users;
create policy "Public profiles are viewable by authenticated users"
on public.users
for select
to authenticated
using (true);

drop policy if exists "Users can update their own profile" on public.users;
create policy "Users can update their own profile"
on public.users
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists "Players can update their match" on public.solo_arena_matches;
create policy "Players can update their match"
on public.solo_arena_matches
for update
to authenticated
using (
  (select auth.uid()) = host_user_id
  or (select auth.uid()) = guest_user_id
)
with check (
  (select auth.uid()) = host_user_id
  or (select auth.uid()) = guest_user_id
);

drop policy if exists "User Upload Photo Notes" on storage.objects;
create policy "User Upload Photo Notes"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'photo_notes'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);;
