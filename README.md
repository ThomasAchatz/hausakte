# Bauakte

Ein Bau-Cockpit für den eigenen Hausbau: Stunden erfassen (mit Wert der
Eigenleistung), Baufortschritt über Phasen verfolgen, Kosten gegen Budget,
Material, Termine, Mängel, Bautagebuch, Fotos und Kontakte — alles an einem
Ort und geräteübergreifend geteilt.

Die App ist eine einzelne HTML-Datei ohne Build-Schritt. Die Daten liegen in
Supabase, sodass sie auf mehreren Geräten dieselben Einträge zeigt.

## Dateien

- `index.html` — die komplette App
- `supabase-setup.sql` — richtet Tabelle, Zugriffsregeln und Foto-Ordner ein
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

## Sicherheit — bitte lesen

Die App ist durch einen **Login** geschützt: Daten und Fotos sind nur für
angemeldete Nutzer sichtbar (Regel `nur_eingeloggt` und die
`authenticated`-Regeln für den Foto-Ordner in `supabase-setup.sql`).

**Nutzer anlegen** im Supabase-Dashboard unter *Authentication → Users →
Add user*: als E-Mail `<benutzername>@hausakte.local` eintragen, ein
Passwort setzen und **Auto Confirm User** anhaken. Beim Login in der App
wird nur der Benutzername eingegeben — das `@hausakte.local` hängt die App
automatisch an. Unter *Authentication → Providers → Email* sollte
**„Allow new users to sign up" ausgeschaltet** sein, damit sich niemand
selbst registrieren kann.

**Fotos:** Der Bucket `fotos` sollte auf **Private** stehen. Die App lädt
Bilder über zeitlich begrenzte, signierte Links — öffentlich erreichbar
sind sie damit nicht.

## Erste Schritte in der App

Zuerst im Reiter **Projekt** Budget, Stundensatz und die Namen setzen. Der
Stundensatz bestimmt den ausgewiesenen Wert der Eigenleistung.
