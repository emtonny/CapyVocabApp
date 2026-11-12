-- Friends mutations belong to authenticated RPCs which lock the whole pair.
-- This migration also stands alone on Production before the Friends rollout.
revoke insert, update, delete, truncate, references, trigger
  on public.friends from public, anon, authenticated;

-- Table-level REVOKE does not remove an independently granted column privilege.
do $$
declare column_name text;
begin
  for column_name in
    select attname from pg_attribute
    where attrelid = 'public.friends'::regclass
      and attnum > 0 and not attisdropped
  loop
    execute format(
      'revoke insert (%1$I), update (%1$I), references (%1$I) on public.friends from public, anon, authenticated',
      column_name
    );
  end loop;
end;
$$;

drop policy if exists "Users manage friend requests" on public.friends;
drop policy if exists "Users view their friend connections" on public.friends;
create policy "Users view their friend connections"
  on public.friends for select to authenticated
  using ((select auth.uid()) = user_id or (select auth.uid()) = friend_id);
grant select on public.friends to authenticated;

revoke all on function public.capture_library_change_event()
  from public, anon, authenticated;
