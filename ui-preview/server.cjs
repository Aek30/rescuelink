// Zero dependencies. Bind to loopback by default; use HOST=0.0.0.0 for LAN previews.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const base = __dirname;
const types = {'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.svg':'image/svg+xml','.webmanifest':'application/manifest+json','.woff2':'font/woff2'};
http.createServer((req,res) => {
  let url;
  try { url = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); } catch { res.writeHead(400); return res.end('Bad request'); }
  const file = path.resolve(base, '.' + (url === '/' ? '/index.html' : url));
  if (!file.startsWith(base + path.sep)) {res.writeHead(403); return res.end('Forbidden');}
  fs.readFile(file, (error,data) => {
    if(error) {res.writeHead(404); return res.end('Not found');}
    res.writeHead(200, {'Content-Type':types[path.extname(file)] || 'application/octet-stream','Cache-Control':'no-cache','X-Content-Type-Options':'nosniff'});
    res.end(data);
  });
}).listen(Number(process.env.PORT || 4173), process.env.HOST || '127.0.0.1', () => console.log('RescueLink preview: http://localhost:' + (process.env.PORT || 4173)));
