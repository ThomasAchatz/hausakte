-- ============================================================
--  Bauakte · Supabase-Setup
--  Im Supabase-Dashboard unter "SQL Editor" einfügen und "Run".
--  Gefahrlos mehrfach ausführbar.
-- ============================================================

-- Tabelle für die App-Daten (Schlüssel/Wert)
create table if not exists bauakte (
  key text primary key,
  value jsonb,
  updated_at timestamptz default now()
);

alter table bauakte enable row level security;

-- Vorläufig offener Zugriff, damit die App sofort läuft.
-- Wird beim Login-Ausbau durch eine strengere Regel ersetzt.
drop policy if exists "offen_vorlaeufig" on bauakte;
create policy "offen_vorlaeufig" on bauakte
  for all using (true) with check (true);

-- ------------------------------------------------------------
-- Fotos-Ordner (Bucket "fotos"): vorläufig offener Zugriff.
-- Voraussetzung: unter "Storage" den Bucket "fotos" anlegen
-- und als "Public" markieren.
-- ------------------------------------------------------------
drop policy if exists "fotos_lesen"     on storage.objects;
drop policy if exists "fotos_schreiben" on storage.objects;
drop policy if exists "fotos_loeschen"  on storage.objects;

create policy "fotos_lesen"     on storage.objects
  for select using (bucket_id = 'fotos');
create policy "fotos_schreiben" on storage.objects
  for insert with check (bucket_id = 'fotos');
create policy "fotos_loeschen"  on storage.objects
  for delete using (bucket_id = 'fotos');
