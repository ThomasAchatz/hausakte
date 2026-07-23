# Bauakte

Ein Bau-Cockpit für den eigenen Hausbau: Stunden erfassen (mit Wert der
Eigenleistung), Firmenstunden getrennt davon mitschreiben, Baufortschritt
über Phasen verfolgen, Kosten gegen Budget, Material, Termine, Mängel,
Bautagebuch, Fotos und Kontakte — alles an einem Ort und geräteübergreifend
geteilt.

Die App ist eine einzelne HTML-Datei ohne Build-Schritt. Die Daten liegen in
Supabase, sodass sie auf mehreren Geräten dieselben Einträge zeigt.

## Dateien

- `index.html` — die komplette App
- `manifest.webmanifest`, `sw.js` — machen die App installierbar (PWA) und
  zeigen Push-Benachrichtigungen an
- `icon-192.png`, `icon-512.png`, `apple-touch-icon.png`, `favicon-32.png` — App-Icons
- `supabase-setup.sql` — Tabelle, Rollen/Zugriffsregeln und Foto-Ordner
- `push-setup.sql` — Tabellen, Auslöser und Zeitplan für Benachrichtigungen
- `supabase/functions/bauakte-push/index.ts` — Edge Function, die die
  Benachrichtigungen verschickt
- `.gitignore`

## Einrichtung

### 1. Supabase vorbereiten

1. Im [Supabase-Dashboard](https://supabase.com/dashboard) das Projekt öffnen.
2. Unter **Storage** einen Bucket namens **`fotos`** anlegen und als
   **Public** markieren.
3. Unter **SQL Editor** den Inhalt von `supabase-setup.sql` einfügen und
   **Run** klicken.

### 2. Zugangsdaten

In `index.html` sind ganz oben im Skript zwei Werte hinterlegt:

```js
const SUPABASE_URL = 'https://…supabase.co';
const SUPABASE_KEY = 'sb_publishable_…';
```

Das ist der **Publishable Key** — er ist für Client-Code gedacht und darf im
Code stehen. Der geheime `sb_secret_…`-Schlüssel gehört **nicht** hier hinein.
Falls du das Projekt wechselst, hier die beiden Werte anpassen.

### 3. Lokal testen

Am einfachsten über einen kleinen lokalen Server:

```bash
python3 -m http.server 8000
```

Dann `http://localhost:8000` im Browser öffnen. (Direktes Öffnen der Datei
per Doppelklick kann je nach Browser an CORS scheitern — der lokale Server
umgeht das.)

### 4. Veröffentlichen mit GitHub Pages

1. Repository zu GitHub pushen.
2. **Settings → Pages → Build and deployment**: Source = *Deploy from a
   branch*, Branch = `main`, Ordner = `/ (root)`, speichern.
3. Nach kurzer Zeit ist die App unter der angezeigten Pages-Adresse
   erreichbar. Weil die Datei `index.html` heißt, wird sie automatisch
   ausgeliefert.

## Geräteübergreifender Abgleich

Einträge werden sofort in Supabase gespeichert. Auf dem anderen Gerät
erscheinen sie beim Öffnen bzw. Zurückwechseln zur App und ansonsten
spätestens nach etwa 15 Sekunden, solange die App offen ist. Bei
gleichzeitigem Bearbeiten gilt: Der zuletzt gespeicherte Stand gewinnt.

## Als App installieren (PWA)

Die App ist installierbar wie die Wetter-App. Nach dem Hosten die
Pages-Adresse im Browser öffnen und:

- **Android/Chrome:** Menü (⋮) → „App installieren" bzw. „Zum Startbildschirm".
- **iOS/Safari:** Teilen-Symbol → „Zum Home-Bildschirm".

Danach liegt die Bauakte mit eigenem Icon als App auf dem Startbildschirm
und startet im Vollbild. Dafür sorgen `manifest.webmanifest`, `sw.js` und
die Icon-Dateien — sie müssen im selben Ordner wie `index.html` liegen.

## Push-Benachrichtigungen einrichten

Isabella und Thomas werden benachrichtigt, wenn die jeweils andere Person
etwas ändert. Regel: **eine einzelne Änderung meldet sofort** (mit Angabe,
was geändert wurde); kommen in den **10 Minuten danach** weitere Änderungen,
werden sie gesammelt und anschließend als **eine** Meldung nachgeschoben.
Über eigene Änderungen wird niemand benachrichtigt. Nur-Lese-Konten lösen
keine Meldungen aus.

> **Achtung — nichts Geheimes ins Repository!** Der private Push-Schlüssel
> und das Geheimwort gehören ausschließlich in die Supabase-Secrets bzw. in
> den SQL Editor. Die Datei `push-setup.sql` enthält bewusst nur den
> Platzhalter `HIER_GEHEIMWORT_EINTRAGEN` — beim Ausführen im SQL Editor
> ersetzen, die *committete* Datei aber mit Platzhalter belassen.

**1. Edge Function deployen.** Im Dashboard unter *Edge Functions → Deploy a
new function*, Name **`bauakte-push`**, und den Inhalt von
`supabase/functions/bauakte-push/index.ts` einfügen. Beim Deployen die
JWT-Prüfung **deaktivieren** („Verify JWT" aus) — die Funktion schützt sich
über ein eigenes Geheimwort.

**2. Secrets setzen.** Unter *Edge Functions → Secrets* diese vier Werte
anlegen (die Werte stehen im Chat, nicht in diesem Repository):
`VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` (z. B.
`mailto:…`) und `PUSH_SECRET`.

**3. `push-setup.sql` ausführen.** Vorher an den **zwei** markierten Stellen
den Platzhalter durch das Geheimwort ersetzen. Das Skript legt die Tabellen
an, verknüpft den Auslöser und richtet den Minuten-Zeitplan fürs Bündeln
ein.

**4. In der App aktivieren.** Jede Person öffnet die Bauakte auf ihrem Handy,
geht auf **Projekt → Benachrichtigungen** und tippt *einschalten*. Auf dem
iPhone funktioniert das **nur mit der zum Home-Bildschirm hinzugefügten
App**, nicht im normalen Safari-Tab.

## Sicherheit & Rollen — bitte lesen

Die App ist durch einen **Login** geschützt: Daten und Fotos sind nur für
angemeldete Nutzer sichtbar und werden durch die Regeln in
`supabase-setup.sql` serverseitig abgesichert.

Es gibt zwei Rollen:

- **Voller Zugriff (bearbeiten):** `isabella2`, `tommy2`.
- **Nur Lesen:** **alle anderen** Konten (z. B. `mama2`, `papa2`,
  `heeeelper`). Sie sehen alles, können aber nichts anlegen, ändern oder
  löschen. Das ist in der App (ausgeblendete Buttons) *und* serverseitig in
  den Zugriffsregeln erzwungen.

Neue **Nur-Lese-Konten** einfach in Supabase anlegen — keine Code-Änderung
nötig. Soll ein neues Konto **bearbeiten** dürfen, muss es in `index.html`
(Liste `EDITORS`) und in `supabase-setup.sql` (die beiden `in (...)`-Listen)
ergänzt werden.

**Nutzer anlegen** im Supabase-Dashboard unter *Authentication → Users →
Add user*: als E-Mail `<benutzername>@hausakte.local` eintragen, ein
Passwort setzen und **Auto Confirm User** anhaken. Beim Login in der App
wird nur der Benutzername eingegeben — das `@hausakte.local` hängt die App
automatisch an. Unter *Authentication → Providers → Email* sollte
**„Allow new users to sign up" ausgeschaltet** sein.

**Fotos:** Der Bucket `fotos` sollte auf **Private** stehen. Die App lädt
Bilder über zeitlich begrenzte, signierte Links — öffentlich erreichbar
sind sie damit nicht.

## Bedienung

**Menü:** oben rechts der Burger — er öffnet eine Schublade von rechts mit
allen Bereichen untereinander.

**Übersicht:** jede Kachel ist antippbar und springt in den passenden
Bereich (Mängel-Kachel → Mängelliste, Ausgaben → Kosten und so weiter).

**Bearbeiten:** jede Zeile antippen öffnet den Eintrag vorausgefüllt zum
Ändern. Das × daneben löscht — allerdings erst nach einer Rückfrage, die
zeigt, welcher Eintrag betroffen ist.

**Monate:** längere Listen (Stunden, Firmen, Kosten, Termine, Tagebuch,
Fotos) sind nach Monaten gruppiert, jeweils mit Monatssumme in der
Zwischenüberschrift.

**Fotos:** Tippen aufs Bild öffnet es im Vollbild; dort lassen sich über
*Bearbeiten* Beschreibung, Datum und Bauphase ändern.

## Erste Schritte in der App

Zuerst im Reiter **Projekt** Budget, Stundensatz und die Namen setzen. Der
Stundensatz bestimmt den ausgewiesenen Wert der Eigenleistung.

**Stunden** sind die eigenen Stunden (ihr beide plus Helfer aus Familie und
Freundeskreis) — daraus errechnet sich die Muskelhypothek. **Firmen** ist
davon getrennt: dort werden Fremdstunden pro Firma mit Anzahl der Arbeiter
erfasst (z. B. „Zimmerei Huber, 3 Arbeiter × 8 h"). Diese Stunden fließen
**nicht** in die Eigenleistung ein und bekommen bewusst keinen Euro-Wert —
sie dienen nur dem Überblick, wer wann mit wie vielen Leuten da war.
