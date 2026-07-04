// Минимальный service worker для PWA-установки веб-версии TypeRIGHTing.
// Стратегия: network-first для навигации (index.html — всегда свежий при онлайне,
// чтобы новый деплой не застревал в кэше), cache-first для остальных ассетов
// (hashed webp/js/css — имена меняются при сборке, старое чистится по версии).
// Поднимать SW_VERSION при значимых изменениях оболочки.
const SW_VERSION = 'tr-v2.56.2';
const CORE = ['./', './index.html', './favicon.png', './apple-touch-icon.png', './manifest.webmanifest'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(SW_VERSION).then((c) => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== SW_VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;

  // Навигация (HTML) — network-first, кэш как офлайн-фолбэк
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req)
        .then((resp) => {
          const cp = resp.clone();
          caches.open(SW_VERSION).then((c) => c.put('./index.html', cp));
          return resp;
        })
        .catch(() => caches.match('./index.html').then((r) => r || caches.match('./')))
    );
    return;
  }

  // Остальное (ассеты) — cache-first, докэшируем same-origin по мере запроса
  e.respondWith(
    caches.match(req).then((cached) => {
      if (cached) return cached;
      return fetch(req).then((resp) => {
        if (resp.ok && req.url.startsWith(self.location.origin)) {
          const cp = resp.clone();
          caches.open(SW_VERSION).then((c) => c.put(req, cp));
        }
        return resp;
      }).catch(() => cached);
    })
  );
});
