-- ============================================================
-- Passageiro — schema completo
-- Rode este arquivo INTEIRO no SQL Editor do Supabase.
-- Pode rodar múltiplas vezes: usa IF NOT EXISTS / OR REPLACE.
-- ============================================================

-- Extensões
create extension if not exists "pgcrypto";

-- ============================================================
-- PROFILES (1:1 com auth.users)
-- ============================================================
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text unique,
  full_name text,
  avatar_url text,
  color text default '#FF385C',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Trigger: cria profile automaticamente quando usuário se cadastra
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- TRIPS
-- ============================================================
create table if not exists public.trips (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  destination text default '',
  start_date date,
  end_date date,
  status text default 'planning' check (status in ('planning','active','archived')),
  archived boolean default false,
  base_currency text default 'BRL',
  secondary_currencies text[] default '{}',
  budget_ceiling numeric(12,2) default 0,
  notes text default '',
  owner_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists trips_owner_idx on public.trips(owner_id);

-- ============================================================
-- TRIP MEMBERS
-- ============================================================
create table if not exists public.trip_members (
  trip_id uuid references public.trips(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  role text default 'editor' check (role in ('owner','editor','viewer')),
  added_at timestamptz default now(),
  primary key (trip_id, user_id)
);

create index if not exists trip_members_user_idx on public.trip_members(user_id);

-- Trigger: quando cria uma trip, adiciona owner como member
create or replace function public.trip_add_owner_as_member()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.trip_members (trip_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists on_trip_created on public.trips;
create trigger on_trip_created
  after insert on public.trips
  for each row execute function public.trip_add_owner_as_member();

-- ============================================================
-- CATEGORIES
-- ============================================================
create table if not exists public.categories (
  id uuid default gen_random_uuid() primary key,
  trip_id uuid references public.trips(id) on delete cascade not null,
  name text not null,
  color text default '#FF385C',
  budgeted numeric(12,2) default 0,
  order_idx int default 0
);
create index if not exists categories_trip_idx on public.categories(trip_id);

-- ============================================================
-- TRAVELERS
-- ============================================================
create table if not exists public.travelers (
  id uuid default gen_random_uuid() primary key,
  trip_id uuid references public.trips(id) on delete cascade not null,
  name text not null,
  color text default '#222222',
  linked_user_id uuid references public.profiles(id),
  order_idx int default 0
);
create index if not exists travelers_trip_idx on public.travelers(trip_id);

-- ============================================================
-- DAYS
-- ============================================================
create table if not exists public.days (
  id uuid default gen_random_uuid() primary key,
  trip_id uuid references public.trips(id) on delete cascade not null,
  date date not null,
  title text default '',
  notes text default ''
);
create index if not exists days_trip_idx on public.days(trip_id);
create index if not exists days_date_idx on public.days(trip_id, date);

-- ============================================================
-- BLOCKS (atividades do dia)
-- ============================================================
create table if not exists public.blocks (
  id uuid default gen_random_uuid() primary key,
  day_id uuid references public.days(id) on delete cascade not null,
  title text not null,
  time text default '',
  location text default '',
  cost numeric(12,2),
  currency text,
  category_id uuid references public.categories(id) on delete set null,
  notes text default '',
  link text default '',
  paid_by uuid references public.travelers(id) on delete set null,
  split_between uuid[] default '{}',
  done boolean default false,
  order_idx int default 0
);
create index if not exists blocks_day_idx on public.blocks(day_id);

-- ============================================================
-- CHECKLIST ITEMS
-- ============================================================
create table if not exists public.checklist_items (
  id uuid default gen_random_uuid() primary key,
  trip_id uuid references public.trips(id) on delete cascade not null,
  text text not null,
  phase text default 'before-book',
  done boolean default false,
  deadline date,
  critical boolean default false,
  notes text default '',
  order_idx int default 0
);
create index if not exists checklist_trip_idx on public.checklist_items(trip_id);

-- ============================================================
-- QUOTES
-- ============================================================
create table if not exists public.quotes (
  id uuid default gen_random_uuid() primary key,
  trip_id uuid references public.trips(id) on delete cascade not null,
  type text default 'flight',
  provider text default '',
  price numeric(12,2),
  currency text,
  benchmark_good numeric(12,2),
  benchmark_ok numeric(12,2),
  benchmark_bad numeric(12,2),
  notes text default '',
  link text default '',
  status text default 'searching',
  created_at timestamptz default now()
);
create index if not exists quotes_trip_idx on public.quotes(trip_id);

-- ============================================================
-- MAP POINTS
-- ============================================================
create table if not exists public.map_points (
  id uuid default gen_random_uuid() primary key,
  trip_id uuid references public.trips(id) on delete cascade not null,
  name text not null,
  lat float8 not null,
  lon float8 not null,
  kind text default 'point',
  note text default '',
  order_idx int default 0
);
create index if not exists map_points_trip_idx on public.map_points(trip_id);

-- ============================================================
-- TRIP INVITES (convites por email)
-- ============================================================
create table if not exists public.trip_invites (
  id uuid default gen_random_uuid() primary key,
  trip_id uuid references public.trips(id) on delete cascade not null,
  invited_email text not null,
  invited_by uuid references public.profiles(id) not null,
  role text default 'editor' check (role in ('editor','viewer')),
  token text default gen_random_uuid()::text unique,
  accepted boolean default false,
  created_at timestamptz default now(),
  expires_at timestamptz default (now() + interval '30 days')
);
create index if not exists trip_invites_email_idx on public.trip_invites(invited_email);
create index if not exists trip_invites_token_idx on public.trip_invites(token);

-- ============================================================
-- FUNÇÃO HELPER: is_trip_member
-- ============================================================
create or replace function public.is_trip_member(_trip_id uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.trip_members
    where trip_id = _trip_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_trip_owner(_trip_id uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.trips
    where id = _trip_id and owner_id = auth.uid()
  );
$$;

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trips_touch on public.trips;
create trigger trips_touch before update on public.trips
  for each row execute function public.touch_updated_at();

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();
