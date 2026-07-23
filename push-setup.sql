-- ============================================================
--  Bauakte · Push-Benachrichtigungen
--  ERST ausführen, wenn die Edge Function "bauakte-push" deployed ist.
--  Im SQL Editor einfügen und "Run". Gefahrlos mehrfach ausführbar.
--
--  WICHTIG: Unten an zwei Stellen das Geheimwort eintragen
--  (steht in der README unter "Push einrichten").
-- ============================================================

-- Erweiterungen (Netzaufrufe aus der Datenbank + Zeitplan)
create extension if not exists pg_net  with schema extensions;
create extension if not exists pg_cron with schema extensions;

-- ------------------------------------------------------------
-- 1) Angemeldete Geräte
-- ------------------------------------------------------------
create table if not exists push_geraete (
  endpoint     text primary key,
  benutzer     text not null,
  subscription jsonb not null,
  updated_at   timestamptz default now()
);
alter table push_geraete enable row level security;

drop policy if exists "geraete_eigene" on push_geraete;
create policy "geraete_eigene" on push_geraete
  for all to authenticated
  using      (benutzer = split_part(auth.jwt() ->> 'email', '@', 1))
  with check (benutzer = split_part(auth.jwt() ->> 'email', '@', 1));

-- ------------------------------------------------------------
-- 2) Änderungs-Protokoll (löst die Meldungen aus)
-- ------------------------------------------------------------
create table if not exists aenderungen (
  id           bigint generated always as identity primary key,
  actor        text not null,
  actor_label  text,
  beschreibung text not null,
  gesendet     boolean not null default false,
  created_at   timestamptz not null default now()
);
create index if not exists aenderungen_offen_idx on aenderungen (actor, gesendet, created_at);
alter table aenderungen enable row level security;

drop policy if exists "aenderungen_schreiben" on aenderungen;
create policy "aenderungen_schreiben" on aenderungen
  for insert to authenticated
  with check ((auth.jwt() ->> 'email') in ('isabella2@hausakte.local','tommy2@hausakte.local'));

drop policy if exists "aenderungen_lesen" on aenderungen;
create policy "aenderungen_lesen" on aenderungen
  for select to authenticated using (true);

-- ------------------------------------------------------------
-- 3) Auslöser: jede neue Änderung meldet sich bei der Funktion
--    >>> GEHEIMWORT unten eintragen <<<
-- ------------------------------------------------------------
create or replace function bauakte_push_sofort()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform net.http_post(
    url     := 'https://lmivqyeuluqtxmpnojgz.supabase.co/functions/v1/bauakte-push',
    body    := jsonb_build_object('modus','sofort','id',new.id),
    headers := jsonb_build_object(
                 'Content-Type','application/json',
                 'x-push-secret','HIER_GEHEIMWORT_EINTRAGEN'
               )
  );
  return new;
end;
$$;

drop trigger if exists trg_bauakte_push on aenderungen;
create trigger trg_bauakte_push
  after insert on aenderungen
  for each row execute function bauakte_push_sofort();

-- ------------------------------------------------------------
-- 4) Zeitplan: prüft jede Minute, ob 10 Min Ruhe war -> Sammelmeldung
--    >>> GEHEIMWORT unten eintragen <<<
-- ------------------------------------------------------------
select cron.unschedule('bauakte-buendel')
  where exists (select 1 from cron.job where jobname = 'bauakte-buendel');

select cron.schedule(
  'bauakte-buendel',
  '* * * * *',
  $$
  select net.http_post(
    url     := 'https://lmivqyeuluqtxmpnojgz.supabase.co/functions/v1/bauakte-push',
    body    := '{"modus":"buendeln"}'::jsonb,
    headers := jsonb_build_object(
                 'Content-Type','application/json',
                 'x-push-secret','HIER_GEHEIMWORT_EINTRAGEN'
               )
  );
  $$
);

-- ------------------------------------------------------------
-- 5) Aufräumen: alte Protokoll-Einträge nach 30 Tagen löschen
-- ------------------------------------------------------------
select cron.unschedule('bauakte-aufraeumen')
  where exists (select 1 from cron.job where jobname = 'bauakte-aufraeumen');

select cron.schedule(
  'bauakte-aufraeumen',
  '17 3 * * *',
  $$ delete from aenderungen where created_at < now() - interval '30 days'; $$
);
