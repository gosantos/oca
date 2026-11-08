// Static server: 127.0.0.1 only, serves only under /<ARTIFACTS_SECRET>/, no listing, no dotfiles, no traversal.
import http from 'node:http'; import fs from 'node:fs'; import path from 'node:path';
const argv = globalThis.Deno ? Deno.args : process.argv.slice(2);
const ROOT = fs.realpathSync(argv[0]); const PORT = Number(argv[1]);
const SECRET = (globalThis.Deno ? Deno.env.get('ARTIFACTS_SECRET') : process.env.ARTIFACTS_SECRET) || '';
const PREFIX = SECRET ? `/${SECRET}` : '';
const T = { '.html':'text/html; charset=utf-8', '.css':'text/css', '.js':'text/javascript', '.json':'application/json',
  '.svg':'image/svg+xml', '.png':'image/png', '.jpg':'image/jpeg', '.webp':'image/webp', '.csv':'text/csv' };
http.createServer((req, res) => {
  const h = { 'X-Content-Type-Options':'nosniff', 'Referrer-Policy':'no-referrer', 'Cache-Control':'no-store', 'X-Robots-Tag':'noindex' };
  const end = (c) => { res.writeHead(c, h); res.end(); };
  if (req.method !== 'GET' && req.method !== 'HEAD') return end(405);
  let u; try { u = decodeURIComponent(new URL(req.url, 'http://x').pathname); } catch { return end(404); }
  if (u === PREFIX) { res.writeHead(301, { ...h, Location: PREFIX + '/' }); return res.end(); }
  if (!u.startsWith(PREFIX + '/')) return end(404);
  u = u.slice(PREFIX.length);
  if (u.split('/').some(s => s.startsWith('.'))) return end(404);
  let f = path.resolve(ROOT, '.' + u);
  try { if (fs.statSync(f).isDirectory()) f = path.join(f, 'index.html'); f = fs.realpathSync(f); } catch { return end(404); }
  if (!f.startsWith(ROOT + path.sep)) return end(404);
  res.writeHead(200, { ...h, 'Content-Type': T[path.extname(f)] || 'application/octet-stream' });
  req.method === 'HEAD' ? res.end() : fs.createReadStream(f).pipe(res);
}).listen(PORT, '127.0.0.1');
