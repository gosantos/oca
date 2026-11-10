// Static server: 127.0.0.1 only, serves only under /<ARTIFACTS_SECRET>/, no listing, no dotfiles, no traversal.
// The site root itself is never served (404), so a stray index.html can't become a public listing.
// Performance: keep-alive, Content-Length, TCP_NODELAY and in-memory gzip for text assets.
import http from 'node:http'; import fs from 'node:fs'; import path from 'node:path'; import zlib from 'node:zlib';
const argv = globalThis.Deno ? Deno.args : process.argv.slice(2);
const env = (k) => { try { return (globalThis.Deno ? Deno.env.get(k) : process.env[k]) ?? ''; } catch { return ''; } };
const ROOT = fs.realpathSync(argv[0]); const PORT = Number(argv[1]);
const SECRET = env('ARTIFACTS_SECRET').trim(); const PUBLIC = env('ARTIFACTS_PUBLIC') === '1';
// Fail closed: a missing or malformed secret must never widen the served paths.
if (!PUBLIC && !/^[0-9a-f]{64}$/.test(SECRET)) {
  console.error('ERROR: ARTIFACTS_SECRET must be 64 lowercase hex chars (or set ARTIFACTS_PUBLIC=1)');
  process.exit(2);
}
const PREFIX = PUBLIC ? '' : `/${SECRET}`;
const T = { '.html':'text/html; charset=utf-8', '.css':'text/css', '.js':'text/javascript', '.json':'application/json',
  '.svg':'image/svg+xml', '.png':'image/png', '.jpg':'image/jpeg', '.webp':'image/webp', '.csv':'text/csv' };
const GZ = new Set(['.html', '.css', '.js', '.json', '.svg', '.csv']); const MAX_GZIP = 1 << 20;
const H = { 'X-Content-Type-Options':'nosniff', 'Referrer-Policy':'no-referrer', 'Cache-Control':'no-store',
  'X-Robots-Tag':'noindex', 'X-Frame-Options':'DENY', 'Content-Security-Policy':"frame-ancestors 'none'" };
const gzCache = new Map(); // path|mtime|size -> gzipped buffer: a shared link gets opened many times
const server = http.createServer((req, res) => {
  const end = (c) => { res.writeHead(c, H); res.end(); };
  if (req.method !== 'GET' && req.method !== 'HEAD') return end(405);
  let u; try { u = decodeURIComponent(new URL(req.url, 'http://x').pathname); } catch { return end(404); }
  if (!PUBLIC && u === PREFIX) { res.writeHead(301, { ...H, Location: PREFIX + '/' }); return res.end(); }
  if (!u.startsWith(PREFIX + '/')) return end(404);
  u = u.slice(PREFIX.length);
  if (u === '/') return end(404);
  if (u.split('/').some(s => s.startsWith('.'))) return end(404);
  let f = path.resolve(ROOT, '.' + u);
  try { if (fs.statSync(f).isDirectory()) f = path.join(f, 'index.html'); f = fs.realpathSync(f); } catch { return end(404); }
  if (!f.startsWith(ROOT + path.sep)) return end(404);
  const ext = path.extname(f).toLowerCase(); const type = T[ext] || 'application/octet-stream';
  fs.stat(f, (err, st) => {
    if (err || !st.isFile()) return end(404);
    const wants = req.method === 'GET' && GZ.has(ext) && st.size <= MAX_GZIP
      && /\bgzip\b/.test(req.headers['accept-encoding'] || '');
    if (!wants) {
      res.writeHead(200, { ...H, 'Content-Type': type, 'Content-Length': st.size });
      return req.method === 'HEAD' ? res.end() : fs.createReadStream(f).pipe(res);
    }
    const key = `${f}|${st.mtimeMs}|${st.size}`;
    const hit = gzCache.get(key);
    if (hit) {
      res.writeHead(200, { ...H, 'Content-Type': type, 'Content-Length': hit.length, 'Content-Encoding': 'gzip', Vary: 'Accept-Encoding' });
      return res.end(hit);
    }
    fs.readFile(f, (e, buf) => {
      if (e) return end(404);
      zlib.gzip(buf, { level: 6 }, (e2, gz) => {
        if (e2) { res.writeHead(200, { ...H, 'Content-Type': type, 'Content-Length': buf.length }); return res.end(buf); }
        if (gzCache.size > 256) gzCache.clear();
        gzCache.set(key, gz);
        res.writeHead(200, { ...H, 'Content-Type': type, 'Content-Length': gz.length, 'Content-Encoding': 'gzip', Vary: 'Accept-Encoding' });
        res.end(gz);
      });
    });
  });
});
server.keepAliveTimeout = 65000; server.headersTimeout = 66000; server.maxRequestsPerSocket = 1000;
server.on('connection', (s) => s.setNoDelay(true));
server.listen(PORT, '127.0.0.1');
