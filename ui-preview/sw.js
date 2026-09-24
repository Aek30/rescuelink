const CACHE = 'rescuelink-preview-v4';
const FILES = ['./', 'index.html', 'styles.css', 'app.js', 'manifest.webmanifest', 'assets/icon.svg', 'assets/NotoSansThai.ttf', 'assets/lucide-icons.js', 'assets/icon-192.png', 'assets/icon-512.png'];
self.addEventListener('install', event => event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(FILES)).then(() => self.skipWaiting())));
self.addEventListener('activate', event => event.waitUntil(Promise.all([
  caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith('rescuelink-preview-') && key !== CACHE).map(key => caches.delete(key)))),
  self.clients.claim()
])));
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET' || new URL(event.request.url).origin !== self.location.origin) return;
  event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request).catch(() => {
    if (event.request.mode === 'navigate') return caches.match('index.html');
    return Response.error();
  })));
});
