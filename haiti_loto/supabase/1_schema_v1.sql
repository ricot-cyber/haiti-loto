-- =====================================================
-- HAITI LOTO - Eskèm Supabase v1
-- Kole nan Supabase > SQL Editor > Run
-- =====================================================

-- 1) PWOFIL (direkte ak vandè) ------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        text not null check (role in ('director','vendor')),
  username    text not null unique,
  full_name   text,
  director_id uuid references public.profiles(id),   -- vandè -> direktè li
  device_id   text,                                   -- ID aparèy (ekran koneksyon)
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- 2) TIRAJ (kòmanse ak 2) -----------------------------
create table if not exists public.draws (
  id         serial primary key,
  code       text not null unique,
  name       text not null,
  draw_time  time not null,                 -- lè tiraj la (orè Ayiti)
  close_before_minutes int not null default 10,
  active     boolean not null default true
);

insert into public.draws (code, name, draw_time) values
  ('NY_MATIN',   'New York Matin',      '12:30'),
  ('GA_APREMIDI','Georgia Aprè-midi',   '18:00')
on conflict (code) do nothing;
-- (ajiste lè yo selon vrè orè yo)

-- 3) JWÈT ---------------------------------------------
create table if not exists public.games (
  code        text primary key,           -- BOLET, MARYAJ, LOTO3, LOTO4, LOTO5
  name        text not null,
  digits      int  not null,
  active      boolean not null default true
);
insert into public.games (code,name,digits) values
  ('BOLET','Bòlèt',2),('MARYAJ','Maryaj',4),
  ('LOTO3','3 Chif',3),('LOTO4','4 Chif',4),('LOTO5','5 Chif',5)
on conflict (code) do nothing;

-- 4) NIMewo BLOKE (direktè kontwole) ------------------
create table if not exists public.blocked_numbers (
  id          bigserial primary key,
  director_id uuid not null references public.profiles(id),
  draw_id     int  references public.draws(id),   -- null = tout tiraj
  game        text not null references public.games(code),
  number      text not null,
  created_at  timestamptz not null default now(),
  unique (director_id, draw_id, game, number)
);

-- 5) LIMIT PA BOUL (total maksimòm pa tiraj) ----------
create table if not exists public.number_limits (
  id          bigserial primary key,
  director_id uuid not null references public.profiles(id),
  draw_id     int  not null references public.draws(id),
  game        text not null references public.games(code),
  number      text not null,
  max_amount  numeric(12,2) not null check (max_amount >= 0),
  unique (director_id, draw_id, game, number)
);

-- 6) FICH AK LIY ---------------------------------------
create table if not exists public.tickets (
  id          bigserial primary key,
  serial      text unique,
  vendor_id   uuid not null references public.profiles(id),
  director_id uuid not null references public.profiles(id),
  draw_id     int  not null references public.draws(id),
  draw_date   date not null default current_date,
  total       numeric(12,2) not null default 0,
  status      text not null default 'active' check (status in ('active','cancelled','paid')),
  created_at  timestamptz not null default now()
);

create table if not exists public.ticket_lines (
  id        bigserial primary key,
  ticket_id bigint not null references public.tickets(id) on delete cascade,
  game      text not null references public.games(code),
  number    text not null,
  amount    numeric(12,2) not null check (amount > 0)
);
create index if not exists idx_lines_lookup on public.ticket_lines (game, number);
create index if not exists idx_tickets_draw on public.tickets (draw_id, draw_date);

-- 7) REZILTA -------------------------------------------
create table if not exists public.results (
  id        bigserial primary key,
  draw_id   int not null references public.draws(id),
  draw_date date not null,
  first     text, second text, third text,   -- 1ye, 2yèm, 3yèm lo
  loto3     text, loto4 text, loto5 text,
  created_at timestamptz not null default now(),
  unique (draw_id, draw_date)
);

-- =====================================================
-- FONKSYON èd
-- =====================================================
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as
$$ select role from profiles where id = auth.uid() $$;

create or replace function public.my_director() returns uuid
language sql stable security definer set search_path = public as
$$ select case when role='director' then id else director_id end
   from profiles where id = auth.uid() $$;

-- =====================================================
-- VANN YON FICH (verifye blokaj + limit sou sèvè)
-- p_lines = [{"game":"BOLET","number":"45","amount":10}, ...]
-- =====================================================
create or replace function public.place_ticket(p_draw_id int, p_lines jsonb)
returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_vendor uuid := auth.uid();
  v_dir uuid; v_ticket bigint; l jsonb;
  v_total numeric := 0; v_sold numeric; v_max numeric;
  v_draw draws%rowtype;
begin
  select director_id into v_dir from profiles
   where id = v_vendor and role='vendor' and active;
  if v_dir is null then raise exception 'Vandè pa otorize'; end if;

  select * into v_draw from draws where id = p_draw_id and active;
  if not found then raise exception 'Tiraj pa disponib'; end if;

  -- tiraj fèmen? (orè Ayiti)
  if (now() at time zone 'America/Port-au-Prince')::time
       >= v_draw.draw_time - make_interval(mins => v_draw.close_before_minutes) then
    raise exception 'Tiraj sa a fèmen';
  end if;

  insert into tickets (vendor_id, director_id, draw_id)
  values (v_vendor, v_dir, p_draw_id) returning id into v_ticket;

  for l in select * from jsonb_array_elements(p_lines) loop
    if exists (select 1 from blocked_numbers b
               where b.director_id = v_dir and b.game = l->>'game'
                 and b.number = l->>'number'
                 and (b.draw_id is null or b.draw_id = p_draw_id)) then
      raise exception 'Nimewo % bloke', l->>'number';
    end if;

    select max_amount into v_max from number_limits
     where director_id=v_dir and draw_id=p_draw_id
       and game=l->>'game' and number=l->>'number';
    if v_max is not null then
      select coalesce(sum(tl.amount),0) into v_sold
        from ticket_lines tl join tickets t on t.id=tl.ticket_id
       where t.director_id=v_dir and t.draw_id=p_draw_id
         and t.draw_date=current_date and t.status<>'cancelled'
         and tl.game=l->>'game' and tl.number=l->>'number';
      if v_sold + (l->>'amount')::numeric > v_max then
        raise exception 'Limit rive pou nimewo %', l->>'number';
      end if;
    end if;

    insert into ticket_lines (ticket_id, game, number, amount)
    values (v_ticket, l->>'game', l->>'number', (l->>'amount')::numeric);
    v_total := v_total + (l->>'amount')::numeric;
  end loop;

  update tickets set total = v_total,
         serial = to_char(now(),'YYMMDD') || '-' || lpad(v_ticket::text,6,'0')
   where id = v_ticket;
  return v_ticket;
end $$;

-- Anile yon fich (vandè a oswa direktè a)
create or replace function public.cancel_ticket(p_ticket bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  update tickets set status='cancelled'
   where id = p_ticket and status='active'
     and (vendor_id = auth.uid() or director_id = auth.uid());
end $$;

-- =====================================================
-- RLS (sekirite)
-- =====================================================
alter table profiles        enable row level security;
alter table draws           enable row level security;
alter table games           enable row level security;
alter table blocked_numbers enable row level security;
alter table number_limits   enable row level security;
alter table tickets         enable row level security;
alter table ticket_lines    enable row level security;
alter table results         enable row level security;

-- profiles
create policy "pwofil: mwen menm oswa vandè m yo" on profiles for select
  using (id = auth.uid() or director_id = auth.uid());
create policy "pwofil: direktè modifye vandè l" on profiles for update
  using (director_id = auth.uid() and my_role()='director');

-- tiraj/jwèt: tout moun konekte li
create policy "draws read"  on draws for select to authenticated using (true);
create policy "games read"  on games for select to authenticated using (true);

-- blokaj ak limit: direktè jere, vandè li sèlman
create policy "blk read"  on blocked_numbers for select
  using (director_id = my_director());
create policy "blk write" on blocked_numbers for all
  using (director_id = auth.uid()) with check (director_id = auth.uid());
create policy "lim read"  on number_limits for select
  using (director_id = my_director());
create policy "lim write" on number_limits for all
  using (director_id = auth.uid()) with check (director_id = auth.uid());

-- fich: vandè wè pa l, direktè wè tout vandè l yo (ekriti pase pa place_ticket)
create policy "tickets read" on tickets for select
  using (vendor_id = auth.uid() or director_id = auth.uid());
create policy "lines read" on ticket_lines for select
  using (exists (select 1 from tickets t where t.id = ticket_id
        and (t.vendor_id = auth.uid() or t.director_id = auth.uid())));

-- rezilta: tout moun li, direktè ekri
create policy "results read"  on results for select to authenticated using (true);
create policy "results write" on results for all
  using (my_role()='director') with check (my_role()='director');

-- =====================================================
-- NÒT: kreye vandè
-- Supabase Auth mande yon imèl. Nou itilize: username@haitiloto.app
-- Direktè kreye vandè atravè yon Edge Function (service_role rete sou sèvè).
-- Premye direktè a: kreye l nan Dashboard > Authentication > Users,
-- epi lanse:
--   insert into profiles (id, role, username)
--   values ('<UUID_USER_LA>', 'director', 'direktè1');
-- =====================================================
