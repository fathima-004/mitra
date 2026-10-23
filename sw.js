// Offline support: serve the app from cache when the network is down,
// but always try the network first so new pushes show up straight away.
const CACHE = 'mitra-v1';
const CORE = [
  './', 'index.html', 'css/style.css', 'js/app.js', 'js/data.js', 'js/calc.js',
  'data/ml.json', 'data/demo.json', 'manifest.webmanifest', 'icons/icon-192.png',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  // Never cache the backend (call, parse) or other sites.
  if (e.request.method !== 'GET' || url.origin !== location.origin || url.pathname.startsWith('/.netlify/')) return;
  e.respondWith(
    fetch(e.request)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy));
        return res;
      })
      .catch(() => caches.match(e.request).then((hit) => hit ?? caches.match('index.html'))),
  );
});
