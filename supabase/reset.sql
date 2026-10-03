-- =====================================================================
-- ALLES ZURÜCKSETZEN (löscht alle Buddy-Tabellen samt Daten!)
-- Nur nötig, wenn schema.sql mit einem Fehler wie
-- 'column "user_id" does not exist' abbricht, weil noch alte Test-Tabellen
-- existieren. Danach schema.sql noch einmal ausführen.
-- Angemeldete Nutzer:innen (Authentication -> Users) bleiben erhalten.
-- =====================================================================

-- alte selbst angelegte Trigger auf auth.users entfernen
do $$
declare t record;
begin
  for t in select tgname from pg_trigger
           where tgrelid = 'auth.users'::regclass and not tgisinternal loop
    execute format('drop trigger if exists %I on auth.users', t.tgname);
  end loop;
end $$;

drop table if exists public.matches  cascade;
drop table if exists public.profiles cascade;
drop table if exists public.admins   cascade;

drop function if exists public.is_admin cascade;
drop function if exists public.is_partner cascade;
drop function if exists public.check_match cascade;
drop function if exists public.handle_confirmed_user cascade;
drop function if exists public.handle_new_user cascade;
