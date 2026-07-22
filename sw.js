/* Bauakte — Service Worker
   Cacht die App-Hülle, damit sie installierbar ist und offline startet.
   Daten/Login (Supabase) und Schriften/CDN laufen immer übers Netz. */
const CACHE = 'bauakte-v1';
const SHELL = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icon-192.png',
  './icon-512.png',
  './apple-touch-icon.png',
  './favicon-32.png'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  const url = new URL(req.url);
  // Fremde Herkunft (Supabase, CDN, Fonts) nicht abfangen — immer aus dem Netz
  if (url.origin !== location.origin) return;
  // Seitenaufrufe: Netz zuerst, sonst die gecachte App-Hülle
  if (req.mode === 'navigate') {
    e.respondWith(fetch(req).catch(() => caches.match('./index.html')));
    return;
  }
  // Übrige eigene Dateien: Cache zuerst, sonst Netz
  e.respondWith(caches.match(req).then(r => r || fetch(req)));
});
