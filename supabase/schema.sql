-- =====================================================================
-- Buddy-Programm – Datenbank für Supabase
-- Supabase -> SQL Editor -> "New query" -> alles einfügen -> "Run".
-- Das Skript kann man mehrmals ausführen, ohne dass Daten verloren gehen.
-- =====================================================================

-- ---------- Alte Test-Versionen aufräumen ----------
-- Tabellen, denen Spalten dieser Version fehlen, stammen aus einem früheren
-- Test und werden gelöscht. Aktuelle Tabellen samt Daten bleiben erhalten.
do $$
declare
  need jsonb := '{
    "admins":   ["user_id"],
    "profiles": ["id","email","role","name","city","uni","field","semester","languages","interests","contact","capacity","consent_at","created_at"],
    "matches":  ["id","neu_id","buddy_id","created_at"]
  }';
  tbl text;
  t record;
begin
  -- matches zuerst prüfen, weil es auf profiles verweist
  foreach tbl in array array['matches','profiles','admins'] loop
    if to_regclass('public.' || tbl) is not null and exists (
      select 1 from jsonb_array_elements_text(need->tbl) c(col)
      where not exists (select 1 from information_schema.columns
                        where table_schema = 'public' and table_name = tbl and column_name = c.col)
    ) then
      raise notice 'Alte Tabelle % wird ersetzt.', tbl;
      execute format('drop table public.%I cascade', tbl);
    end if;
  end loop;

  -- alte selbst angelegte Trigger auf auth.users entfernen (unserer wird unten neu angelegt)
  for t in select tgname from pg_trigger
           where tgrelid = 'auth.users'::regclass and not tgisinternal loop
    execute format('drop trigger if exists %I on auth.users', t.tgname);
  end loop;
end $$;

-- Funktionen neu anlegen (die Regeln, die sie benutzen, entstehen weiter unten neu)
drop function if exists public.is_admin cascade;
drop function if exists public.is_partner cascade;
drop function if exists public.handle_new_user cascade;

-- ---------- Tabellen ----------

-- Wer hier eingetragen ist, sieht die Admin-Ansicht.
create table if not exists public.admins (
  user_id uuid primary key references auth.users on delete cascade
);

-- Ein Profil pro angemeldeter Person (neue:r Stipi oder Buddy).
create table if not exists public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  email       text not null,
  role        text not null check (role in ('neu','buddy')),
  name        text not null check (char_length(name) between 1 and 100),
  city        text,
  uni         text check (char_length(uni) <= 120),
  field       text,
  semester    int  not null default 1 check (semester between 1 and 20),
  languages   text[] not null default '{}',
  interests   text[] not null default '{}',
  contact     text not null default 'beides' check (contact in ('persönlich','online','beides')),
  capacity    int  not null default 0 check (capacity between 0 and 3),
  consent_at  timestamptz,
  created_at  timestamptz not null default now()
);

-- Bestätigte Paare. Jede:r Neue hat höchstens einen Buddy.
create table if not exists public.matches (
  id          uuid primary key default gen_random_uuid(),
  neu_id      uuid not null unique references public.profiles on delete cascade,
  buddy_id    uuid not null references public.profiles on delete cascade,
  created_at  timestamptz not null default now()
);

-- Einstellungen, die das Admin-Team auf der Website ändert (z. B. der Einladungscode)
create table if not exists public.settings (
  key   text primary key,
  value text
);

-- Nur zum Prüfen des Einladungscodes beim Anlegen, wird danach geleert
alter table public.profiles add column if not exists invite_code text;

-- ---------- Hilfsfunktionen ----------

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- true, wenn die angemeldete Person mit "other" ein Paar bildet
create or replace function public.is_partner(other uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.matches
    where (neu_id = auth.uid() and buddy_id = other)
       or (buddy_id = auth.uid() and neu_id = other)
  );
$$;

-- true, wenn mit dieser E-Mail schon ein bestätigtes Konto existiert
-- (das Anmeldeformular verhindert damit doppelte Registrierungen)
create or replace function public.email_registered(e text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from auth.users
    where lower(email) = lower(trim(e)) and email_confirmed_at is not null
  );
$$;

revoke all on function public.email_registered(text) from public;
grant execute on function public.email_registered(text) to anon, authenticated;
grant execute on function public.is_admin() to authenticated;

-- ---------- Einladungscode ----------
-- Ist kein Code gesetzt, kann sich jede:r registrieren.

create or replace function public.current_invite_code()
returns text language sql stable security definer set search_path = public as $$
  select nullif(trim(value), '') from public.settings where key = 'invite_code';
$$;
revoke all on function public.current_invite_code() from public, anon, authenticated;

create or replace function public.invite_required()
returns boolean language sql stable security definer set search_path = public as $$
  select public.current_invite_code() is not null;
$$;

create or replace function public.check_invite(c text)
returns boolean language sql stable security definer set search_path = public as $$
  select case when public.current_invite_code() is null then true
              else lower(trim(coalesce(c, ''))) = lower(public.current_invite_code()) end;
$$;

revoke all on function public.invite_required() from public;
revoke all on function public.check_invite(text) from public;
grant execute on function public.invite_required() to anon, authenticated;
grant execute on function public.check_invite(text) to anon, authenticated;

-- Wer sein Profil selbst über die Website anlegt, braucht den richtigen Code
create or replace function public.check_profile_invite()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() and not public.check_invite(new.invite_code) then
    raise exception 'Der Einladungscode stimmt nicht.';
  end if;
  new.invite_code := null;
  return new;
end $$;

drop trigger if exists check_profile_invite on public.profiles;
create trigger check_profile_invite before insert on public.profiles
  for each row execute function public.check_profile_invite();
grant execute on function public.is_partner(uuid) to authenticated;

-- ---------- Paare prüfen: richtige Rollen, Buddy hat noch Platz ----------

create or replace function public.check_match()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  cap int;
  used int;
begin
  if not exists (select 1 from public.profiles where id = new.neu_id and role = 'neu') then
    raise exception 'Die erste Person ist keine neue Stipendiatin / kein neuer Stipendiat.';
  end if;
  select capacity into cap from public.profiles where id = new.buddy_id and role = 'buddy';
  if cap is null then
    raise exception 'Die zweite Person ist kein Buddy.';
  end if;
  -- Sperre, damit "Alle bestätigen" die Plätze nicht überbucht
  perform pg_advisory_xact_lock(hashtext(new.buddy_id::text));
  select count(*) into used from public.matches where buddy_id = new.buddy_id;
  if used >= cap then
    raise exception 'Dieser Buddy hat keinen freien Platz mehr.';
  end if;
  return new;
end $$;

drop trigger if exists check_match on public.matches;
create trigger check_match before insert on public.matches
  for each row execute function public.check_match();

-- ---------- Profil ändern: Rolle und E-Mail bleiben, Plätze nicht unter Belegung ----------

create or replace function public.protect_profile()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  used int;
begin
  -- über die Website (nicht im SQL Editor) dürfen nur Admins diese Felder ändern
  if auth.uid() is not null and not public.is_admin() then
    new.id         := old.id;
    new.role       := old.role;
    new.email      := old.email;
    new.consent_at := old.consent_at;
    new.created_at := old.created_at;
  end if;
  if new.role = 'neu' then
    new.capacity := 0;
  else
    select count(*) into used from public.matches where buddy_id = new.id;
    if new.capacity < greatest(used, 1) then
      raise exception 'Du begleitest schon % Person(en). Weniger Plätze gehen erst, wenn ein Paar aufgelöst wurde.', used;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists protect_profile on public.profiles;
create trigger protect_profile before update on public.profiles
  for each row execute function public.protect_profile();

-- ---------- Profil automatisch anlegen, sobald die E-Mail bestätigt ist ----------
-- Die Website schickt die Formulardaten beim Registrieren mit (raw_user_meta_data).

create or replace function public.handle_confirmed_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  d jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  r text  := d->>'role';
  sem int;
  cap int;
begin
  if new.email_confirmed_at is null or r is null or r not in ('neu','buddy') then
    return new;
  end if;
  -- falscher Einladungscode: kein Profil (die Website fragt dann erneut nach dem Code)
  if not public.check_invite(d->>'invite_code') then
    return new;
  end if;

  sem := case when d->>'semester' ~ '^\d{1,2}$' then (d->>'semester')::int else 1 end;
  cap := case when d->>'capacity' ~ '^\d$' then (d->>'capacity')::int else 1 end;

  insert into public.profiles
    (id, email, role, name, city, uni, field, semester, languages, interests, contact, capacity, consent_at, invite_code)
  values (
    new.id,
    lower(new.email),
    r,
    coalesce(nullif(left(trim(d->>'name'), 100), ''), split_part(new.email, '@', 1)),
    d->>'city',
    left(d->>'uni', 120),
    d->>'field',
    least(greatest(sem, 1), 20),
    case when jsonb_typeof(d->'languages') = 'array'
         then array(select jsonb_array_elements_text(d->'languages')) else '{}' end,
    case when jsonb_typeof(d->'interests') = 'array'
         then array(select jsonb_array_elements_text(d->'interests')) else '{}' end,
    case when d->>'contact' in ('persönlich','online','beides') then d->>'contact' else 'beides' end,
    case when r = 'buddy' then least(greatest(cap, 1), 3) else 0 end,
    now(),
    d->>'invite_code'
  )
  on conflict (id) do nothing;
  return new;
exception when others then
  -- Ein fehlerhaftes Profil darf nie den Login blockieren.
  raise warning 'Profil für % konnte nicht angelegt werden: %', new.email, sqlerrm;
  return new;
end $$;

drop trigger if exists on_auth_user_confirmed on auth.users;
create trigger on_auth_user_confirmed
  after insert or update of email_confirmed_at on auth.users
  for each row execute function public.handle_confirmed_user();

-- ---------- Zugriffsrechte (Row Level Security) ----------
-- Wichtig: Der "Publishable key" steht öffentlich in index.html.
-- Nur diese Regeln verhindern, dass Fremde Daten lesen.

alter table public.admins   enable row level security;
alter table public.profiles enable row level security;
alter table public.matches  enable row level security;
alter table public.settings enable row level security;

-- settings: nur Admins lesen und ändern
drop policy if exists "settings admin" on public.settings;
create policy "settings admin" on public.settings for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- admins: niemand liest oder schreibt über die Website (nur über den SQL Editor)

-- profiles: das eigene Profil, das Profil des eigenen Buddys bzw. der eigenen Neuen; Admins sehen alle
drop policy if exists "profiles lesen" on public.profiles;
create policy "profiles lesen" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin() or public.is_partner(id));

drop policy if exists "eigenes Profil anlegen" on public.profiles;
create policy "eigenes Profil anlegen" on public.profiles for insert to authenticated
  with check (id = auth.uid() and lower(email) = lower(auth.jwt()->>'email'));

drop policy if exists "eigenes Profil ändern" on public.profiles;
create policy "eigenes Profil ändern" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "Profil löschen" on public.profiles;
create policy "Profil löschen" on public.profiles for delete to authenticated
  using (id = auth.uid() or public.is_admin());

-- matches: Beteiligte sehen ihr Paar; nur Admins bestätigen oder lösen auf
drop policy if exists "matches lesen" on public.matches;
create policy "matches lesen" on public.matches for select to authenticated
  using (public.is_admin() or neu_id = auth.uid() or buddy_id = auth.uid());

drop policy if exists "matches anlegen" on public.matches;
create policy "matches anlegen" on public.matches for insert to authenticated
  with check (public.is_admin());

drop policy if exists "matches löschen" on public.matches;
create policy "matches löschen" on public.matches for delete to authenticated
  using (public.is_admin());

-- =====================================================================
-- DICH ALS ADMIN EINTRAGEN (erst nachdem du unter Authentication -> Users
-- deine E-Mail als Nutzer:in angelegt hast). E-Mail anpassen, dann nur
-- diese Zeile markieren und ausführen:
--
-- insert into public.admins (user_id)
--   select id from auth.users where email = 'deine@email.de'
--   on conflict do nothing;
-- =====================================================================
