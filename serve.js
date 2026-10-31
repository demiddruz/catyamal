// Tiny static server for the prototype: node serve.js [port]
// If the port is already taken by another copy of this server (a second window started it),
// this process stays up as a lightweight watcher instead of crashing, and takes over if that copy exits.
const http = require('http'), fs = require('fs'), path = require('path');
const root = __dirname, port = +(process.env.PORT || process.argv[2] || 8768);
const types = {'.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.webp': 'image/webp', '.jpg': 'image/jpeg', '.json': 'application/json', '.ogg': 'audio/ogg', '.txt': 'text/plain; charset=utf-8'};

function handler(req, res) {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p === '/') p = '/index.html';
  const f = path.join(root, p);
  if (!f.startsWith(root) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(404); return res.end('not found'); }
  res.writeHead(200, {'Content-Type': types[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'no-store'});
  fs.createReadStream(f).pipe(res);
}

function isOurs(cb) { // does the process on the port serve this game?
  http.get({ host: 'localhost', port, path: '/' }, r => { let b = ''; r.on('data', d => b += d); r.on('end', () => cb(b.includes('<title>Кот против Мальчика</title>'))); })
    .on('error', () => cb(false));
}

function start() {
  const srv = http.createServer(handler);
  srv.on('error', e => {
    if (e.code !== 'EADDRINUSE') throw e;
    isOurs(ours => {
      if (!ours) { console.error('Port ' + port + ' is used by another program'); process.exit(1); }
      console.log('Catyamal already running on http://localhost:' + port + ' (shared with another window)');
      const t = setInterval(() => isOurs(still => { if (!still) { clearInterval(t); start(); } }), 3000);
    });
  });
  srv.listen(port, () => console.log('Long Nick on http://localhost:' + port));
}
start();
