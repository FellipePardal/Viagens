-- ============================================================
-- Fix: log_activity() com fallback quando auth.uid() é null
-- (ex: updates via superuser, triggers em cascade)
-- ============================================================

CREATE OR REPLACE FUNCTION public.log_activity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  actor uuid := auth.uid();
  actor_name text;
  the_trip uuid;
  ent_type text;
  ent_id uuid;
  ent_name text;
  action text;
  summary text;
BEGIN
  IF TG_OP = 'INSERT' THEN action := 'create';
  ELSIF TG_OP = 'UPDATE' THEN action := 'update';
  ELSIF TG_OP = 'DELETE' THEN action := 'delete';
  END IF;

  IF TG_TABLE_NAME = 'blocks' THEN
    ent_type := 'block';
    ent_id := coalesce(NEW.id, OLD.id);
    SELECT trip_id INTO the_trip FROM public.days WHERE id = coalesce(NEW.day_id, OLD.day_id);
    ent_name := coalesce(NEW.title, OLD.title);
  ELSIF TG_TABLE_NAME = 'options' THEN
    ent_type := 'option';
    ent_id := coalesce(NEW.id, OLD.id);
    the_trip := coalesce(NEW.trip_id, OLD.trip_id);
    ent_name := coalesce(NEW.name, OLD.name);
    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
      action := 'status';
    END IF;
  ELSIF TG_TABLE_NAME = 'checklist_items' THEN
    ent_type := 'checklist';
    ent_id := coalesce(NEW.id, OLD.id);
    the_trip := coalesce(NEW.trip_id, OLD.trip_id);
    ent_name := coalesce(NEW.text, OLD.text);
    IF TG_OP = 'UPDATE' AND OLD.done IS DISTINCT FROM NEW.done THEN
      action := CASE WHEN NEW.done THEN 'done' ELSE 'undone' END;
    END IF;
  ELSIF TG_TABLE_NAME = 'quotes' THEN
    ent_type := 'quote';
    ent_id := coalesce(NEW.id, OLD.id);
    the_trip := coalesce(NEW.trip_id, OLD.trip_id);
    ent_name := coalesce(NEW.provider, OLD.provider);
  ELSIF TG_TABLE_NAME = 'days' THEN
    ent_type := 'day';
    ent_id := coalesce(NEW.id, OLD.id);
    the_trip := coalesce(NEW.trip_id, OLD.trip_id);
    ent_name := coalesce(NEW.title, OLD.title, 'dia');
  ELSIF TG_TABLE_NAME = 'trip_members' THEN
    ent_type := 'member';
    ent_id := coalesce(NEW.user_id, OLD.user_id);
    the_trip := coalesce(NEW.trip_id, OLD.trip_id);
    SELECT coalesce(full_name, email) INTO ent_name FROM public.profiles WHERE id = ent_id;
    action := CASE WHEN TG_OP = 'INSERT' THEN 'invite' ELSE 'delete' END;
  END IF;

  IF the_trip IS NULL THEN RETURN coalesce(NEW, OLD); END IF;

  -- Se actor é null (ex: via superuser/trigger interno), pula log
  IF actor IS NULL THEN RETURN coalesce(NEW, OLD); END IF;

  actor_name := coalesce(public._actor_name(actor), 'alguém');
  ent_name := coalesce(ent_name, '?');

  summary := actor_name || ' ' || CASE action
    WHEN 'create' THEN 'adicionou'
    WHEN 'update' THEN 'editou'
    WHEN 'delete' THEN 'apagou'
    WHEN 'status' THEN 'mudou status de'
    WHEN 'done'   THEN 'marcou como feito:'
    WHEN 'undone' THEN 'desmarcou:'
    WHEN 'invite' THEN 'entrou em'
    ELSE action
  END || ' ' || ent_type || ' "' || ent_name || '"';

  -- Fallback defensivo: se ainda ficou null, usa placeholder
  IF summary IS NULL THEN summary := 'atividade registrada'; END IF;

  INSERT INTO public.activity_log (trip_id, actor_id, kind, entity_type, entity_id, summary, payload)
  VALUES (the_trip, actor, action, ent_type, ent_id, summary, '{}'::jsonb);

  RETURN coalesce(NEW, OLD);
END;
$$;
