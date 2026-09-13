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

drop policy if exists "trips_select_members" on public.trips;
create policy "trips_select_members" on public.trips
for select using (public.is_trip_member(id));

drop policy if exists "trips_insert_own" on public.trips;
create policy "trips_insert_own" on public.trips
for insert with check (owner_id = auth.uid());

drop policy if exists "trips_update_members" on public.trips;
create policy "trips_update_members" on public.trips
for update using (public.is_trip_member(id));

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
