-- ============================================================
-- Passageiro — políticas RLS (Row Level Security)
-- Rode DEPOIS do schema.sql
-- ============================================================

-- PROFILES ----------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own_or_teammates" on public.profiles;
create policy "profiles_select_own_or_teammates" on public.profiles
for select using (
  id = auth.uid()
  or id in (
    select tm.user_id from public.trip_members tm
    where tm.trip_id in (
      select trip_id from public.trip_members where user_id = auth.uid()
    )
  )
);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
for insert with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
for update using (id = auth.uid());

-- TRIPS -------------------------------------------------------
alter table public.trips enable row level security;

-- Owner sempre pode ver e editar direto (evita bug do INSERT ... RETURNING
-- avaliar SELECT policy antes do trigger AFTER inserir em trip_members).
drop policy if exists "trips_select_members" on public.trips;
create policy "trips_select_members" on public.trips
for select using (owner_id = auth.uid() or public.is_trip_member(id));

drop policy if exists "trips_insert_own" on public.trips;
create policy "trips_insert_own" on public.trips
for insert with check (owner_id = auth.uid());

drop policy if exists "trips_update_members" on public.trips;
create policy "trips_update_members" on public.trips
for update using (owner_id = auth.uid() or public.is_trip_member(id));

drop policy if exists "trips_delete_owner" on public.trips;
create policy "trips_delete_owner" on public.trips
for delete using (owner_id = auth.uid());

-- TRIP MEMBERS -----------------------------------------------
alter table public.trip_members enable row level security;

drop policy if exists "trip_members_select" on public.trip_members;
create policy "trip_members_select" on public.trip_members
for select using (public.is_trip_member(trip_id));

drop policy if exists "trip_members_manage_owner" on public.trip_members;
create policy "trip_members_manage_owner" on public.trip_members
for all using (public.is_trip_owner(trip_id));

-- CATEGORIES / TRAVELERS / DAYS / CHECKLIST / QUOTES / MAP_POINTS --
-- (todas seguem mesmo padrão: membro da trip faz tudo)

do $$
declare tab text;
begin
  foreach tab in array array['categories','travelers','days','checklist_items','quotes','map_points']
  loop
    execute format('alter table public.%I enable row level security', tab);
    execute format('drop policy if exists "%I_all_members" on public.%I', tab, tab);
    execute format('create policy "%I_all_members" on public.%I for all using (public.is_trip_member(trip_id))', tab, tab);
  end loop;
end $$;

-- BLOCKS (não tem trip_id direto — via day_id)
alter table public.blocks enable row level security;

drop policy if exists "blocks_all_members" on public.blocks;
create policy "blocks_all_members" on public.blocks
for all using (
  exists (
    select 1 from public.days d
    where d.id = day_id and public.is_trip_member(d.trip_id)
  )
);

-- ACCEPT INVITE RPC (SECURITY DEFINER) ----------------------
-- Permitem que um user aceite convites feitos ao seu email
-- sem bater na policy `trip_members_manage_owner` (que só permite dono inserir).

CREATE OR REPLACE FUNCTION public.accept_pending_invites()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  my_email text; cnt int := 0; r record;
BEGIN
  SELECT email INTO my_email FROM auth.users WHERE id = auth.uid();
  IF my_email IS NULL THEN RETURN 0; END IF;
  FOR r IN
    SELECT id, trip_id, role FROM public.trip_invites
    WHERE lower(invited_email) = lower(my_email)
      AND accepted = false
      AND (expires_at IS NULL OR expires_at > now())
  LOOP
    INSERT INTO public.trip_members (trip_id, user_id, role)
    VALUES (r.trip_id, auth.uid(), COALESCE(r.role, 'editor'))
    ON CONFLICT (trip_id, user_id) DO NOTHING;
    UPDATE public.trip_invites SET accepted = true WHERE id = r.id;
    cnt := cnt + 1;
  END LOOP;
  RETURN cnt;
END;
$$;
GRANT EXECUTE ON FUNCTION public.accept_pending_invites() TO authenticated;

CREATE OR REPLACE FUNCTION public.accept_invite_token(_token text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE inv record; my_email text;
BEGIN
  SELECT email INTO my_email FROM auth.users WHERE id = auth.uid();
  IF my_email IS NULL THEN RETURN NULL; END IF;
  SELECT * INTO inv FROM public.trip_invites
    WHERE token = _token AND accepted = false
      AND (expires_at IS NULL OR expires_at > now());
  IF NOT FOUND THEN RETURN NULL; END IF;
  IF lower(inv.invited_email) != lower(my_email) THEN
    RAISE EXCEPTION 'Convite endereçado a outro email (%). Faça login com esse email.', inv.invited_email;
  END IF;
  INSERT INTO public.trip_members (trip_id, user_id, role)
  VALUES (inv.trip_id, auth.uid(), COALESCE(inv.role, 'editor'))
  ON CONFLICT (trip_id, user_id) DO NOTHING;
  UPDATE public.trip_invites SET accepted = true WHERE id = inv.id;
  RETURN inv.trip_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.accept_invite_token(text) TO authenticated;

-- TRIP INVITES -----------------------------------------------
alter table public.trip_invites enable row level security;

drop policy if exists "trip_invites_select_owner" on public.trip_invites;
create policy "trip_invites_select_owner" on public.trip_invites
for select using (public.is_trip_owner(trip_id) or invited_email = (select email from public.profiles where id = auth.uid()));

drop policy if exists "trip_invites_insert_owner" on public.trip_invites;
create policy "trip_invites_insert_owner" on public.trip_invites
for insert with check (public.is_trip_owner(trip_id));

drop policy if exists "trip_invites_update_invitee" on public.trip_invites;
create policy "trip_invites_update_invitee" on public.trip_invites
for update using (invited_email = (select email from public.profiles where id = auth.uid()));

drop policy if exists "trip_invites_delete_owner" on public.trip_invites;
create policy "trip_invites_delete_owner" on public.trip_invites
for delete using (public.is_trip_owner(trip_id));
