-- ============================================================
-- Módulo Opções (candidatos pra decisão colaborativa)
-- Rode DEPOIS do schema.sql + policies.sql
-- ============================================================

-- OPTIONS -----------------------------------------------------
create table if not exists public.options (
  id uuid default gen_random_uuid() primary key,
  trip_id uuid references public.trips(id) on delete cascade not null,
  type text default 'hotel' check (type in ('hotel','restaurant','activity','transport','flight','other')),
  name text not null,
  location text default '',
  lat float8,
  lon float8,
  price numeric(12,2),
  currency text,
  price_unit text default '',
  link text default '',
  image_url text default '',
  notes text default '',
  status text default 'considering' check (status in ('considering','preferred','booked','discarded')),
  linked_day_id uuid references public.days(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  order_idx int default 0
);
create index if not exists options_trip_idx on public.options(trip_id);

-- OPTION_VOTES ------------------------------------------------
create table if not exists public.option_votes (
  option_id uuid references public.options(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  vote text not null check (vote in ('up','down','love')),
  created_at timestamptz default now(),
  primary key (option_id, user_id)
);
create index if not exists option_votes_option_idx on public.option_votes(option_id);

-- OPTION_COMMENTS ---------------------------------------------
create table if not exists public.option_comments (
  id uuid default gen_random_uuid() primary key,
  option_id uuid references public.options(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete set null,
  text text not null,
  created_at timestamptz default now()
);
create index if not exists option_comments_option_idx on public.option_comments(option_id);

-- Touch updated_at
drop trigger if exists options_touch on public.options;
create trigger options_touch before update on public.options
  for each row execute function public.touch_updated_at();

-- ============================================================
-- RLS
-- ============================================================

-- Options: membros da trip fazem tudo
alter table public.options enable row level security;
drop policy if exists options_all_members on public.options;
create policy options_all_members on public.options
  for all using (public.is_trip_member(trip_id))
  with check (public.is_trip_member(trip_id));

-- Votes: membros veem e cada um vota como si mesmo
alter table public.option_votes enable row level security;
drop policy if exists option_votes_select on public.option_votes;
create policy option_votes_select on public.option_votes
  for select using (
    exists (select 1 from public.options o where o.id = option_id and public.is_trip_member(o.trip_id))
  );
drop policy if exists option_votes_write on public.option_votes;
create policy option_votes_write on public.option_votes
  for all using (
    user_id = auth.uid() and exists (select 1 from public.options o where o.id = option_id and public.is_trip_member(o.trip_id))
  )
  with check (
    user_id = auth.uid() and exists (select 1 from public.options o where o.id = option_id and public.is_trip_member(o.trip_id))
  );

-- Comments: membros veem, cada um cria/apaga o próprio
alter table public.option_comments enable row level security;
drop policy if exists option_comments_select on public.option_comments;
create policy option_comments_select on public.option_comments
  for select using (
    exists (select 1 from public.options o where o.id = option_id and public.is_trip_member(o.trip_id))
  );
drop policy if exists option_comments_insert on public.option_comments;
create policy option_comments_insert on public.option_comments
  for insert with check (
    user_id = auth.uid() and exists (select 1 from public.options o where o.id = option_id and public.is_trip_member(o.trip_id))
  );
drop policy if exists option_comments_delete on public.option_comments;
create policy option_comments_delete on public.option_comments
  for delete using (user_id = auth.uid());

-- ============================================================
-- Realtime
-- ============================================================
do $$
declare tab text;
begin
  foreach tab in array array['options','option_votes','option_comments']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', tab);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;
