-- ============================================================
--  Bauakte · Supabase-Setup (mit Login)
--  Im Supabase-Dashboard unter "SQL Editor" einfügen und "Run".
--  Gefahrlos mehrfach ausführbar.
-- ============================================================

-- 1) Tabelle für die App-Daten (Schlüssel/Wert)
create table if not exists bauakte (
  key text primary key,
  value jsonb,
  updated_at timestamptz default now()
);
alter table bauakte enable row level security;

-- 2) Zugriff NUR für angemeldete Nutzer
drop policy if exists "offen_vorlaeufig" on bauakte;
drop policy if exists "nur_eingeloggt"   on bauakte;
create policy "nur_eingeloggt" on bauakte
  for all to authenticated using (true) with check (true);

-- 3) Fotos-Ordner (Bucket "fotos"): nur für angemeldete Nutzer
--    Voraussetzung: unter "Storage" den Bucket "fotos" anlegen.
--    Empfehlung: Bucket auf PRIVATE stellen (die App nutzt signierte Links).
drop policy if exists "fotos_lesen"     on storage.objects;
drop policy if exists "fotos_schreiben" on storage.objects;
drop policy if exists "fotos_loeschen"  on storage.objects;
create policy "fotos_lesen"     on storage.objects for select to authenticated using (bucket_id = 'fotos');
create policy "fotos_schreiben" on storage.objects for insert to authenticated with check (bucket_id = 'fotos');
create policy "fotos_loeschen"  on storage.objects for delete to authenticated using (bucket_id = 'fotos');

-- ------------------------------------------------------------
-- Nutzer werden NICHT per SQL angelegt, sondern im Dashboard:
--   Authentication -> Users -> Add user
--   E-Mail = <benutzername>@hausakte.local, Passwort setzen,
--   Haken "Auto Confirm User" setzen.
-- Zusätzlich: Authentication -> Providers -> Email ->
--   "Allow new users to sign up" ausschalten.
-- ------------------------------------------------------------
