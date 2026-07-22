-- ============================================================
--  Bauakte · Supabase-Setup (Login + Rollen)
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

-- 2) Rechte auf die Daten
--    Lesen: alle angemeldeten Nutzer.
--    Schreiben/Löschen: NUR die Bearbeiter isabella2 und tommy2.
--    Alle anderen Konten (mama2, papa2, heeeelper, …) können also nur lesen.
drop policy if exists "offen_vorlaeufig"      on bauakte;
drop policy if exists "nur_eingeloggt"        on bauakte;
drop policy if exists "schreiben_ohne_helfer" on bauakte;
drop policy if exists "lesen_alle"            on bauakte;
drop policy if exists "schreiben_nur_owner"   on bauakte;

create policy "lesen_alle" on bauakte
  for select to authenticated using (true);

create policy "schreiben_nur_owner" on bauakte
  for all to authenticated
  using      ((auth.jwt() ->> 'email') in ('isabella2@hausakte.local','tommy2@hausakte.local'))
  with check ((auth.jwt() ->> 'email') in ('isabella2@hausakte.local','tommy2@hausakte.local'));

-- 3) Fotos-Ordner (Bucket "fotos"): Bucket auf PRIVATE stellen.
--    Lesen: alle angemeldeten. Hochladen/Löschen: nur die Bearbeiter.
drop policy if exists "fotos_lesen"     on storage.objects;
drop policy if exists "fotos_schreiben" on storage.objects;
drop policy if exists "fotos_loeschen"  on storage.objects;

create policy "fotos_lesen" on storage.objects
  for select to authenticated using (bucket_id = 'fotos');

create policy "fotos_schreiben" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'fotos' and (auth.jwt() ->> 'email') in ('isabella2@hausakte.local','tommy2@hausakte.local'));

create policy "fotos_loeschen" on storage.objects
  for delete to authenticated
  using (bucket_id = 'fotos' and (auth.jwt() ->> 'email') in ('isabella2@hausakte.local','tommy2@hausakte.local'));

-- ------------------------------------------------------------
-- Nutzer im Dashboard anlegen (nicht per SQL):
--   Authentication -> Users -> Add user
--   E-Mail = <benutzername>@hausakte.local, Passwort, Haken "Auto Confirm User".
-- Bearbeiter: isabella2, tommy2.  Nur Lesen: alle anderen (z. B. mama2, papa2).
-- Wer NEU bearbeiten darf, muss oben in beiden 'in (...)'-Listen ergänzt werden.
-- Registrierung sperren: Authentication -> Providers -> Email ->
--   "Allow new users to sign up" ausschalten.
-- ------------------------------------------------------------
