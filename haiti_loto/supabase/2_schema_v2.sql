-- =====================================================
-- HAITI LOTO - Eskèm v2  (lanse APRE 1_schema_v1.sql)
-- =====================================================

-- ---- Pwofil: komisyon + telefòn
alter table public.profiles add column if not exists commission_pct numeric(5,2) not null default 10;
alter table public.profiles add column if not exists phone text;

-- ---- Tiraj: lè fèmen (jan sa parèt sou app la)
alter table public.draws add column if not exists close_time time;
update public.draws set close_time = '14:25' where code = 'NY_MATIN'    and close_time is null;
update public.draws set close_time = '18:55' where code = 'GA_APREMIDI' and close_time is null;
alter table public.draws alter column close_time set not null;

-- ---- Paramèt direktè
create table if not exists public.director_settings (
  director_id    uuid primary key references public.profiles(id) on delete cascade,
  bank_name      text,
  support_phone  text,
  cancel_minutes int not null default 5
);

-- ---- To peman (si pa gen liy pou direktè a, valè pa defo itilize)
create table if not exists public.payout_rates (
  director_id uuid not null references public.profiles(id) on delete cascade,
  game        text not null references public.games(code),
  pos         int  not null default 1,
  multiplier  numeric not null,
  primary key (director_id, game, pos)
);

-- ---- ID piblik fich (timestamp-4chif, tankou Sagaloto)
alter table public.tickets add column if not exists public_id text unique;

-- ---- RLS
alter table public.director_settings enable row level security;
alter table public.payout_rates      enable row level security;

drop policy if exists "settings read"  on director_settings;
drop policy if exists "settings write" on director_settings;
create policy "settings read"  on director_settings for select using (director_id = my_director());
create policy "settings write" on director_settings for all
  using (director_id = auth.uid()) with check (director_id = auth.uid());

drop policy if exists "rates read"  on payout_rates;
drop policy if exists "rates write" on payout_rates;
create policy "rates read"  on payout_rates for select using (director_id = my_director());
create policy "rates write" on payout_rates for all
  using (director_id = auth.uid()) with check (director_id = auth.uid());

-- ---- Aparèy: yon vandè = yon machin
create or replace function public.register_device(p_device text)
returns void language plpgsql security definer set search_path = public as $$
declare cur text;
begin
  select device_id into cur from profiles where id = auth.uid();
  if cur is null then
    update profiles set device_id = p_device where id = auth.uid();
  elsif cur <> p_device and (select role from profiles where id = auth.uid()) = 'vendor' then
    raise exception 'Kont sa a lye ak yon lòt aparèy. Kontakte direktè a.';
  end if;
end $$;

-- ---- Vann yon fich (ranplase v1)
create or replace function public.place_ticket(p_draw_id int, p_lines jsonb)
returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_vendor uuid := auth.uid();
  v_dir uuid; v_ticket bigint; l jsonb;
  v_total numeric := 0; v_sold numeric; v_max numeric;
  v_draw draws%rowtype;
  v_now timestamp := now() at time zone 'America/Port-au-Prince';
begin
  select director_id into v_dir from profiles
   where id = v_vendor and role='vendor' and active;
  if v_dir is null then raise exception 'Vandè pa otorize'; end if;

  select * into v_draw from draws where id = p_draw_id and active;
  if not found then raise exception 'Tiraj pa disponib'; end if;
  if v_now::time >= v_draw.close_time then raise exception 'Tiraj % fèmen', v_draw.name; end if;

  insert into tickets (vendor_id, director_id, draw_id, draw_date, public_id)
  values (v_vendor, v_dir, p_draw_id, v_now::date,
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
       where t.director_id=v_dir and t.draw_id=p_draw_id and t.draw_date=v_now::date
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

-- ---- Anile fich (pa ID piblik)
create or replace function public.cancel_ticket_by_public(p_public text)
returns void language plpgsql security definer set search_path = public as $$
declare
  t tickets%rowtype; s director_settings%rowtype; d draws%rowtype;
  v_now timestamp := now() at time zone 'America/Port-au-Prince';
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
    if t.draw_date < v_now::date or (t.draw_date = v_now::date and v_now::time >= d.close_time) then
      raise exception 'Tiraj la fèmen';
    end if;
  end if;
  update tickets set status = 'cancelled' where id = t.id;
end $$;

-- ---- Peman pa defo (PLASEHOLDER - modifye nan payout_rates selon règ ou yo)
create or replace function public.payout_rate(p_dir uuid, p_game text, p_pos int)
returns numeric language sql stable as $$
  select coalesce(
    (select multiplier from payout_rates where director_id = p_dir and game = p_game and pos = p_pos),
    case p_game
      when 'BOLET'  then case p_pos when 1 then 60 when 2 then 20 else 10 end
      when 'MARYAJ' then 1000
      when 'LOTO3'  then 500
      when 'LOTO4'  then 5000
      when 'LOTO5'  then 25000
      else 0 end)
$$;

create or replace function public.line_payout(l public.ticket_lines, r public.results, p_dir uuid)
returns numeric language plpgsql stable as $$
declare pos int; a text; b text;
begin
  if r.id is null then return 0; end if;
  if l.game = 'BOLET' then
    pos := case when l.number = r.first then 1 when l.number = r.second then 2
                when l.number = r.third then 3 end;
    if pos is null then return 0; end if;
    return l.amount * payout_rate(p_dir, 'BOLET', pos);
  elsif l.game = 'MARYAJ' then
    a := split_part(l.number, '-', 1); b := split_part(l.number, '-', 2);
    if a <> b and a in (r.first, r.second, r.third) and b in (r.first, r.second, r.third) then
      return l.amount * payout_rate(p_dir, 'MARYAJ', 1);
    end if;
    return 0;
  elsif l.game = 'LOTO3' and l.number = r.loto3 then return l.amount * payout_rate(p_dir, 'LOTO3', 1);
  elsif l.game = 'LOTO4' and l.number = r.loto4 then return l.amount * payout_rate(p_dir, 'LOTO4', 1);
  elsif l.game = 'LOTO5' and l.number = r.loto5 then return l.amount * payout_rate(p_dir, 'LOTO5', 1);
  end if;
  return 0;
end $$;

-- ---- Rapò (vandè: pa l sèlman | direktè: tout vandè l yo oswa yon sèl)
create or replace function public.sales_report(
  p_from date, p_to date, p_draw int default null, p_vendor uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_role text; v_uid uuid := auth.uid(); v_dir uuid; v_vendor uuid; res jsonb;
begin
  select role into v_role from profiles where id = v_uid;
  if v_role = 'vendor' then
    v_vendor := v_uid; select director_id into v_dir from profiles where id = v_uid;
  else
    v_dir := v_uid; v_vendor := p_vendor;
  end if;

  with t as (
    select tk.id, tk.total, pv.commission_pct as cp,
      (select coalesce(sum(line_payout(l, r, v_dir)), 0)
         from ticket_lines l
         left join results r on r.draw_id = tk.draw_id and r.draw_date = tk.draw_date
        where l.ticket_id = tk.id) as pay
    from tickets tk join profiles pv on pv.id = tk.vendor_id
    where tk.status <> 'cancelled' and tk.director_id = v_dir
      and tk.draw_date between p_from and p_to
      and (p_draw is null or tk.draw_id = p_draw)
      and (v_vendor is null or tk.vendor_id = v_vendor)
  )
  select jsonb_build_object(
    'tickets',    count(*),
    'win',        count(*) filter (where pay > 0),
    'lost',       count(*) filter (where pay = 0),
    'sales',      coalesce(sum(total), 0),
    'payout',     coalesce(sum(pay), 0),
    'commission', coalesce(sum(total * cp / 100), 0),
    'balance',    coalesce(sum(total - pay - total * cp / 100), 0)
  ) into res from t;
  return res;
end $$;

-- Itilizatè konekte ka rele fonksyon yo
grant execute on function public.place_ticket(int, jsonb)           to authenticated;
grant execute on function public.cancel_ticket_by_public(text)      to authenticated;
grant execute on function public.register_device(text)              to authenticated;
grant execute on function public.sales_report(date, date, int, uuid) to authenticated;
