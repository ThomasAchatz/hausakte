/* Bauakte — Service Worker
   1) Cacht die App-Hülle (installierbar, startet offline)
   2) Empfängt Push-Benachrichtigungen und zeigt sie an */
const CACHE = 'bauakte-v2';
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
  if (req.mode === 'navigate') {
    e.respondWith(fetch(req).catch(() => caches.match('./index.html')));
    return;
  }
  e.respondWith(caches.match(req).then(r => r || fetch(req)));
});

/* ---------- Push ---------- */
self.addEventListener('push', event => {
  let payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch (e) {
    payload = { titel: 'Bauakte', text: event.data ? event.data.text() : 'Es gibt Updates' };
  }
  const titel = payload.titel || 'Bauakte';
  const text  = payload.text  || 'Es gibt Updates';
  event.waitUntil(
    self.registration.showNotification(titel, {
      body: text,
      icon: './icon-192.png',
      badge: './icon-192.png',
      tag: payload.tag || 'bauakte-update',
      renotify: true,
      data: { url: './' }
    })
  );
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const ziel = new URL((event.notification.data && event.notification.data.url) || './', self.location.href).href;
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      for (const c of list) {
        if (c.url.startsWith(self.registration.scope) && 'focus' in c) return c.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow(ziel);
    })
  );
});
