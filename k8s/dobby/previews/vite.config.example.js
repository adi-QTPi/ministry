// Merge these settings into the project's existing config; retain its plugins.
import { defineConfig } from 'vite';

const port = Number(process.env.DOBBY_PREVIEW_PORT || 5173);
const host = process.env.DOBBY_PREVIEW_HOST;
if (!Number.isInteger(port) || port < 3000 || port > 5999 || !host) {
  throw new Error('Set DOBBY_PREVIEW_HOST and a DOBBY_PREVIEW_PORT in 3000..5999');
}

export default defineConfig({
  base: `/live/${port}/`,
  server: {
    host: '127.0.0.1',
    port,
    strictPort: true,
    allowedHosts: [host],
    hmr: { protocol: 'wss', host, clientPort: 443 },
  },
});
