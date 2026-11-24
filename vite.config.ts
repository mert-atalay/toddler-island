import { defineConfig, type Plugin } from 'vite';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));

// Dev-only endpoint: the lineup and sound picker pages POST the parent's choices here,
// and they are written to choices/<name>.json in the project so the next build step can read them.
function saveChoices(): Plugin {
  return {
    name: 'save-choices',
    configureServer(server) {
      server.middlewares.use('/api/choices', (req, res) => {
        const name = (req.url || '').replace(/^\//, '').replace(/[^a-z0-9-]/gi, '');
        const file = path.join(root, 'choices', `${name || 'misc'}.json`);
        if (req.method === 'GET') {
          res.setHeader('Content-Type', 'application/json');
          res.end(fs.existsSync(file) ? fs.readFileSync(file) : '{}');
          return;
        }
        let body = '';
        req.on('data', (c) => (body += c));
        req.on('end', () => {
          try {
            const parsed = JSON.parse(body);
            fs.mkdirSync(path.dirname(file), { recursive: true });
            fs.writeFileSync(file, JSON.stringify({ savedAt: new Date().toISOString(), ...parsed }, null, 2));
            res.end('{"ok":true}');
          } catch (e) {
            res.statusCode = 400;
            res.end(JSON.stringify({ ok: false, error: String(e) }));
          }
        });
      });
    },
  };
}

export default defineConfig({
  plugins: [saveChoices()],
  server: { port: 5180 },
  build: {
    rollupOptions: {
      input: {
        main: path.join(root, 'index.html'),
        play: path.join(root, 'play.html'),
        lineup: path.join(root, 'lineup.html'),
        sounds: path.join(root, 'sounds.html'),
        soundCheck: path.join(root, 'sound-check.html'),
      },
    },
  },
});
