-- ============================================================
-- Fase 2 + 4: activity_log, mentions, assignee, storage bucket
-- ============================================================

-- ACTIVITY_LOG ------------------------------------------------
create table if not exists public.activity_log (
  id uuid default gen_random_uuid() primary key,
  trip_id uuid references public.trips(id) on delete cascade not null,
  actor_id uuid references public.profiles(id) on delete set null,
  kind text not null,               -- 'create' | 'update' | 'delete' | 'vote' | 'comment' | 'status' | 'invite'
  entity_type text not null,        -- 'block' | 'option' | 'checklist' | 'quote' | 'day' | 'member' | 'trip'
  entity_id uuid,
  summary text not null,            -- texto pronto pra exibir
  payload jsonb default '{}'::jsonb,
  at timestamptz default now()
);
create index if not exists activity_log_trip_at_idx on public.activity_log(trip_id, at desc);

alter table public.activity_log enable row level security;
drop policy if exists activity_log_read on public.activity_log;
create policy activity_log_read on public.activity_log
  for select using (public.is_trip_member(trip_id));
drop policy if exists activity_log_insert on public.activity_log;
create policy activity_log_insert on public.activity_log
  for insert with check (public.is_trip_member(trip_id));

-- Helper: pega nome amigavel do user
create or replace function public._actor_name(_uid uuid) returns text
language sql security definer stable set search_path = public as $$
  select coalesce(full_name, email, 'alguém') from public.profiles where id = _uid;
$$;

-- Trigger genérico: registra em activity_log ao mudar blocks/options/checklist/quotes/days
create or replace function public.log_activity()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  actor uuid := auth.uid();
  actor_name text;
  the_trip uuid;
  ent_type text;
  ent_id uuid;
  ent_name text;
  action text;
  summary text;
begin
  if TG_OP = 'INSERT' then action := 'create';
  elsif TG_OP = 'UPDATE' then action := 'update';
  elsif TG_OP = 'DELETE' then action := 'delete';
  end if;

  -- Descobre trip_id + entity_type + friendly name
  if TG_TABLE_NAME = 'blocks' then
    ent_type := 'block';
    ent_id := coalesce(new.id, old.id);
    select trip_id into the_trip from public.days where id = coalesce(new.day_id, old.day_id);
    ent_name := coalesce(new.title, old.title);
  elsif TG_TABLE_NAME = 'options' then
    ent_type := 'option';
    ent_id := coalesce(new.id, old.id);
    the_trip := coalesce(new.trip_id, old.trip_id);
    ent_name := coalesce(new.name, old.name);
    -- refinar quando muda só status
    if TG_OP = 'UPDATE' and old.status is distinct from new.status then
      action := 'status';
    end if;
  elsif TG_TABLE_NAME = 'checklist_items' then
    ent_type := 'checklist';
    ent_id := coalesce(new.id, old.id);
    the_trip := coalesce(new.trip_id, old.trip_id);
    ent_name := coalesce(new.text, old.text);
    if TG_OP = 'UPDATE' and old.done is distinct from new.done then
      action := case when new.done then 'done' else 'undone' end;
    end if;
  elsif TG_TABLE_NAME = 'quotes' then
    ent_type := 'quote';
    ent_id := coalesce(new.id, old.id);
    the_trip := coalesce(new.trip_id, old.trip_id);
    ent_name := coalesce(new.provider, old.provider);
  elsif TG_TABLE_NAME = 'days' then
    ent_type := 'day';
    ent_id := coalesce(new.id, old.id);
    the_trip := coalesce(new.trip_id, old.trip_id);
    ent_name := coalesce(new.title, old.title, 'dia');
  elsif TG_TABLE_NAME = 'trip_members' then
    ent_type := 'member';
    ent_id := coalesce(new.user_id, old.user_id);
    the_trip := coalesce(new.trip_id, old.trip_id);
    select coalesce(full_name, email) into ent_name from public.profiles where id = ent_id;
    action := case when TG_OP = 'INSERT' then 'invite' else 'delete' end;
  end if;

  if the_trip is null then return coalesce(new, old); end if;

  actor_name := public._actor_name(actor);
  summary := actor_name || ' ' || case action
    when 'create' then 'adicionou'
    when 'update' then 'editou'
    when 'delete' then 'apagou'
    when 'status' then 'mudou status de'
    when 'done'   then 'marcou como feito:'
    when 'undone' then 'desmarcou:'
    when 'invite' then 'entrou em'
    else action
  end || ' ' || ent_type || ' "' || coalesce(ent_name, '?') || '"';

  insert into public.activity_log (trip_id, actor_id, kind, entity_type, entity_id, summary, payload)
  values (the_trip, actor, action, ent_type, ent_id, summary, '{}'::jsonb);

  return coalesce(new, old);
end;
$$;

-- Aplica triggers
do $$
declare tab text;
begin
  foreach tab in array array['blocks','options','checklist_items','quotes','days','trip_members']
  loop
    execute format('drop trigger if exists log_%I on public.%I', tab, tab);
    execute format('create trigger log_%I after insert or update or delete on public.%I for each row execute function public.log_activity()', tab, tab);
  end loop;
end $$;

-- Realtime
do $$
begin
  begin
    alter publication supabase_realtime add table public.activity_log;
  exception when duplicate_object then null;
  end;
end $$;

-- MENTIONS em option_comments -------------------------------
alter table public.option_comments add column if not exists mentioned_users uuid[] default '{}';

-- ASSIGNEE em checklist_items -------------------------------
alter table public.checklist_items add column if not exists assignee_id uuid references public.profiles(id) on delete set null;
