-- ============================================================
-- Auto-promove opção pra 'preferred' quando todos os membros
-- da viagem votaram positivo (up ou love) e status ainda é 'considering'
-- ============================================================

CREATE OR REPLACE FUNCTION public.check_option_consensus()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  opt_id uuid;
  opt_trip_id uuid;
  opt_status text;
  n_members int;
  n_positive_votes int;
BEGIN
  opt_id := coalesce(NEW.option_id, OLD.option_id);
  SELECT o.trip_id, o.status INTO opt_trip_id, opt_status
    FROM public.options o WHERE o.id = opt_id;
  IF opt_status != 'considering' THEN RETURN NEW; END IF;

  SELECT COUNT(*) INTO n_members FROM public.trip_members WHERE trip_id = opt_trip_id;
  IF n_members < 2 THEN RETURN NEW; END IF;

  SELECT COUNT(DISTINCT v.user_id)
    INTO n_positive_votes
    FROM public.option_votes v
    JOIN public.trip_members tm ON tm.user_id = v.user_id AND tm.trip_id = opt_trip_id
    WHERE v.option_id = opt_id AND v.vote IN ('up','love');

  IF n_positive_votes >= n_members THEN
    UPDATE public.options SET status = 'preferred', updated_at = now()
      WHERE id = opt_id AND status = 'considering';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_vote_check_consensus ON public.option_votes;
CREATE TRIGGER on_vote_check_consensus
  AFTER INSERT OR UPDATE ON public.option_votes
  FOR EACH ROW EXECUTE FUNCTION public.check_option_consensus();
