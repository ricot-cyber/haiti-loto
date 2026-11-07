-- =====================================================
-- HAITI LOTO v4
--  1) Pri (to peman) modifye pa direktè
--  2) Lè tiraj yo kalkile otomatik (lè Etazini -> lè Brezil), fèmen 10 min avan
--  3) Kalkil rezilta apati Pick 3 + Pick 4
--  4) Lajan (R$) chwazi pa direktè
-- Lanse APRE v1, v2 ak supabase_fizo_brezil.sql
-- =====================================================

-- ---------- 1) Paramèt direktè: lajan
alter table public.director_settings add column if not exists currency text not null default 'R$';

-- Pri pa defo (direktè a ka modifye yo nan app la, tab "Pri")
create or replace function public.payout_rate(p_dir uuid, p_game text, p_pos int)
returns numeric language sql stable as $$
  select coalesce(
    (select multiplier from payout_rates where director_id = p_dir and game = p_game and pos = p_pos),
    case p_game
      when 'BOLET'  then case p_pos when 1 then 50 when 2 then 20 else 10 end
      when 'MARYAJ' then 500
      when 'LOTO3'  then 750
      when 'LOTO4'  then 5000
      when 'LOTO5'  then 0      -- pa defini ankò: mete l nan tab Pri
      else 0 end)
$$;

-- ---------- 2) Tiraj: lè nan lè Etazini, konvèsyon otomatik
alter table public.draws add column if not exists draw_tz text not null default 'America/New_York';
alter table public.draws alter column close_time drop not null;

drop policy if exists "draws director write" on public.draws;
create policy "draws director write" on public.draws for all
  using (my_role() = 'director') with check (my_role() = 'director');

update public.draws set active = false;
insert into public.draws (code, name, draw_time, close_before_minutes, draw_tz, active) values
  ('GA_MATIN', 'Georgia Matin', '12:29', 10, 'America/New_York', true),
  ('FL_MATIN', 'Florida Matin', '13:30', 10, 'America/New_York', true),
  ('NY_MATIN', 'NewYork Matin', '14:30', 10, 'America/New_York', true),
  ('GA_ASWE',  'Georgia Aswè',  '18:59', 10, 'America/New_York', true),
  ('FL_ASWE',  'Florida Aswè',  '21:45', 10, 'America/New_York', true),
  ('NY_ASWE',  'NewYork Aswè',  '22:30', 10, 'America/New_York', true)
on conflict (code) do update set
  name = excluded.name, draw_time = excluded.draw_time,
  close_before_minutes = excluded.close_before_minutes,
  draw_tz = excluded.draw_tz, active = true;

-- Eta chak tiraj kounye a (lè fèmen an lè Brezil, tan ki rete, louvri/fèmen)
create or replace function public.draws_today()
returns table (id int, code text, name text, is_open boolean, secs_left int,
               close_local text, draw_local text)
language plpgsql stable security definer set search_path = public as $$
declare
  d draws%rowtype;
  v_local timestamp; v_draw timestamp; v_close timestamp;
  v_close_tz timestamptz; v_draw_tz timestamptz;
begin
  for d in select * from draws where draws.active order by draws.draw_time loop
    v_local := now() at time zone d.draw_tz;
    v_draw  := date_trunc('day', v_local) + d.draw_time;
    v_close := v_draw - make_interval(mins => d.close_before_minutes);
    if v_local < v_close then
      is_open := true;
    else
      is_open := false;
      v_draw  := v_draw  + interval '1 day';
      v_close := v_close + interval '1 day';
    end if;
    v_close_tz := v_close at time zone d.draw_tz;
    v_draw_tz  := v_draw  at time zone d.draw_tz;
    id := d.id; code := d.code; name := d.name;
    secs_left   := greatest(0, extract(epoch from (v_close_tz - now()))::int);
    close_local := to_char(v_close_tz at time zone public.app_tz(), 'HH24:MI');
    draw_local  := to_char(v_draw_tz  at time zone public.app_tz(), 'HH24:MI');
    return next;
  end loop;
end $$;
grant execute on function public.draws_today() to authenticated;

-- Vann yon fich
create or replace function public.place_ticket(p_draw_id int, p_lines jsonb)
returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_vendor uuid := auth.uid();
  v_dir uuid; v_ticket bigint; l jsonb;
  v_total numeric := 0; v_sold numeric; v_max numeric;
  v_draw draws%rowtype;
  v_local timestamp; v_date date;
begin
  select director_id into v_dir from profiles
   where id = v_vendor and role='vendor' and active;
  if v_dir is null then raise exception 'Vandè pa otorize'; end if;

  select * into v_draw from draws where id = p_draw_id and active;
  if not found then raise exception 'Tiraj pa disponib'; end if;

  v_local := now() at time zone v_draw.draw_tz;
  v_date  := v_local::date;
  if v_local >= (v_date + v_draw.draw_time) - make_interval(mins => v_draw.close_before_minutes) then
    raise exception 'Tiraj % fèmen', v_draw.name;
  end if;

  insert into tickets (vendor_id, director_id, draw_id, draw_date, public_id)
  values (v_vendor, v_dir, p_draw_id, v_date,
          floor(extract(epoch from now()))::bigint::text || '-' || lpad(floor(random()*10000)::int::text, 4, '0'))
  returning id into v_ticket;

  for l in select * from jsonb_array_elements(p_lines) loop
    if (l->>'amount')::numeric <= 0 then raise exception 'Kòb pa valid'; end if;

    if exists (select 1 from blocked_numbers b
               where b.director_id = v_dir and b.game = l->>'game' and b.number = l->>'number'
                 and (b.draw_id is null or b.draw_id = p_draw_id)) then
      raise exception 'Nimewo % bloke', l->>'number';
    end if;

    select max_amount into v_max from number_limits
     where director_id=v_dir and draw_id=p_draw_id and game=l->>'game' and number=l->>'number';
    if v_max is not null then
      select coalesce(sum(tl.amount),0) into v_sold
        from ticket_lines tl join tickets t on t.id=tl.ticket_id
       where t.director_id=v_dir and t.draw_id=p_draw_id and t.draw_date=v_date
         and t.status<>'cancelled' and tl.game=l->>'game' and tl.number=l->>'number';
      if v_sold + (l->>'amount')::numeric > v_max then
        raise exception 'Limit rive pou nimewo %', l->>'number';
      end if;
    end if;

    insert into ticket_lines (ticket_id, game, number, amount)
    values (v_ticket, l->>'game', l->>'number', (l->>'amount')::numeric);
    v_total := v_total + (l->>'amount')::numeric;
  end loop;

  update tickets set total = v_total where id = v_ticket;
  return v_ticket;
end $$;

-- Anile fich
create or replace function public.cancel_ticket_by_public(p_public text)
returns void language plpgsql security definer set search_path = public as $$
declare
  t tickets%rowtype; s director_settings%rowtype; d draws%rowtype;
begin
  select * into t from tickets
   where public_id = p_public and (vendor_id = auth.uid() or director_id = auth.uid());
  if not found then raise exception 'Fich pa jwenn'; end if;
  if t.status <> 'active' then raise exception 'Fich sa a pa ka anile'; end if;

  if t.vendor_id = auth.uid() then
    select * into s from director_settings where director_id = t.director_id;
    select * into d from draws where id = t.draw_id;
    if now() - t.created_at > make_interval(mins => coalesce(s.cancel_minutes, 5)) then
      raise exception 'Delè pou anile a pase';
    end if;
    if (now() at time zone d.draw_tz) >= (t.draw_date + d.draw_time) - make_interval(mins => d.close_before_minutes) then
      raise exception 'Tiraj la fèmen';
    end if;
  end if;
  update tickets set status = 'cancelled' where id = t.id;
end $$;

-- ---------- 3) Rezilta apati Pick 3 + Pick 4
-- HIPOTÈZ (konfime ak rezilta Sagaloto):
--   1ye lo = 2 dènye chif Pick 3 | 2yèm lo = 2 premye chif Pick 4 | 3yèm lo = 2 dènye chif Pick 4
--   Loto3 = Pick 3 | Loto4 = Pick 4 | Loto5 = Pick 3 + 2 premye chif Pick 4
create or replace function public.apply_picks(p_draw_code text, p_date date, p_pick3 text, p_pick4 text)
returns void language plpgsql security definer set search_path = public as $$
declare v_draw int;
begin
  if auth.uid() is not null
     and coalesce((select role from profiles where id = auth.uid()), '') <> 'director' then
    raise exception 'Se direktè sèlman';
  end if;
  if p_pick3 !~ '^[0-9]{3}$' or p_pick4 !~ '^[0-9]{4}$' then
    raise exception 'Pick 3 dwe gen 3 chif, Pick 4 dwe gen 4 chif';
  end if;
  select id into v_draw from draws where code = p_draw_code;
  if v_draw is null then raise exception 'Tiraj pa jwenn'; end if;

  insert into results (draw_id, draw_date, first, second, third, loto3, loto4, loto5)
  values (v_draw, p_date, right(p_pick3, 2), left(p_pick4, 2), right(p_pick4, 2),
          p_pick3, p_pick4, p_pick3 || left(p_pick4, 2))
  on conflict (draw_id, draw_date) do update set
    first = excluded.first, second = excluded.second, third = excluded.third,
    loto3 = excluded.loto3, loto4 = excluded.loto4, loto5 = excluded.loto5;
end $$;
grant execute on function public.apply_picks(text, date, text, text) to authenticated, service_role;

select * from public.draws_today();
