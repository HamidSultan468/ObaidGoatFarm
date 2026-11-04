// Serves the built Flutter web app (app/build/web) for the desktop launcher.
// Bound to 127.0.0.1 only, so it is never reachable from the network.
// Usage: node serve-web.mjs <buildDir> <port>
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, resolve, sep } from 'node:path';

const root = resolve(process.argv[2] ?? 'build/web');
const port = Number(process.argv[3] ?? 8770);

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.css': 'text/css',
  '.frag': 'text/plain',
};

async function send(req, res, file) {
  const info = await stat(file);
  if (!info.isFile()) throw new Error('not a file');
  // Flutter's main.dart.js is not content-hashed, so a max-age would keep the
  // OLD app after a rebuild. Always revalidate; unchanged files cost a 304.
  const etag = `"${info.size.toString(16)}-${Math.floor(info.mtimeMs).toString(16)}"`;
  const headers = {
    'content-type': TYPES[extname(file)] ?? 'application/octet-stream',
    'cache-control': 'no-cache',
    etag,
    'x-content-type-options': 'nosniff',
  };
  if (req.headers['if-none-match'] === etag) {
    res.writeHead(304, headers).end();
    return;
  }
  res.writeHead(200, headers);
  res.end(await readFile(file));
}

createServer(async (req, res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    const file = resolve(join(root, pathname));
    // Path traversal guard: anything outside the build folder is refused.
    if (file !== root && !file.startsWith(root + sep)) {
      res.writeHead(400).end();
      return;
    }
    try {
      await send(req, res, pathname === '/' ? join(root, 'index.html') : file);
    } catch {
      // SPA fallback: deep links like /goat-farm/animals/<id> load the app shell.
      await send(req, res, join(root, 'index.html'));
    }
  } catch {
    res.writeHead(500).end();
  }
}).listen(port, '127.0.0.1', () => console.log(`Tangent web app on http://localhost:${port} (from ${root})`));
