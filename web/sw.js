// Offline support: serve the app from cache when the network is down,
// but always try the network first so new pushes show up straight away.
const CACHE = 'mitra-v12';
const CORE = [
  './', 'index.html', 'setup.html', 'daily.html', 'profit.html', 'money.html', 'join.html', 'call.html', 'schemes.html', 'support.html', 'bulk.html', 'css/style.css', 'js/app.js', 'js/icons.js', 'js/data.js', 'js/calc.js', 'js/money.js', 'js/art.js', 'js/insights.js', 'js/call.js', 'js/parse.js',
  'data/ml.json', 'data/demo.json', 'data/limits.json', 'data/join_call.json', 'data/schemes.json', 'manifest.webmanifest', 'icons/icon-192.png',
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
    // 'no-cache' = always ask the server if the file changed, so new pushes show up immediately.
    fetch(e.request, { cache: 'no-cache' })
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy));
        return res;
      })
      .catch(() => caches.match(e.request).then((hit) => hit ?? caches.match('index.html'))),
  );
});
