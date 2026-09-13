-- ============================================================
-- Passageiro — habilitar realtime nas tabelas
-- Rode DEPOIS do schema + policies
-- ============================================================

-- Publica as tabelas para realtime
do $$
declare tab text;
begin
  foreach tab in array array[
    'trips','trip_members','categories','travelers',
    'days','blocks','checklist_items','quotes','map_points','trip_invites','profiles'
  ]
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', tab);
    exception when duplicate_object then
      -- já está publicada, ignora
      null;
    end;
  end loop;
end $$;
