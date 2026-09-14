-- ============================================================
-- Auto-criar traveler para cada membro da viagem
-- + backfill dos membros existentes que ainda nao tem traveler
-- ============================================================

CREATE OR REPLACE FUNCTION public.ensure_traveler_for_member()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  user_name text;
  user_color text;
BEGIN
  SELECT COALESCE(full_name, email, 'Membro'), COALESCE(color, '#222222')
    INTO user_name, user_color
    FROM public.profiles WHERE id = NEW.user_id;
  INSERT INTO public.travelers (trip_id, name, color, linked_user_id)
  SELECT NEW.trip_id, user_name, user_color, NEW.user_id
  WHERE NOT EXISTS (
    SELECT 1 FROM public.travelers WHERE trip_id = NEW.trip_id AND linked_user_id = NEW.user_id
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_member_add_traveler ON public.trip_members;
CREATE TRIGGER on_member_add_traveler
  AFTER INSERT ON public.trip_members
  FOR EACH ROW EXECUTE FUNCTION public.ensure_traveler_for_member();

-- Backfill: cria travelers para membros existentes
INSERT INTO public.travelers (trip_id, name, color, linked_user_id)
SELECT tm.trip_id,
       COALESCE(p.full_name, p.email, 'Membro'),
       COALESCE(p.color, '#222222'),
       tm.user_id
FROM public.trip_members tm
JOIN public.profiles p ON p.id = tm.user_id
WHERE NOT EXISTS (
  SELECT 1 FROM public.travelers t
   WHERE t.trip_id = tm.trip_id AND t.linked_user_id = tm.user_id
);
