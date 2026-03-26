require('dotenv').config();
const express    = require('express');
const cors       = require('cors');
const helmet     = require('helmet');
const rateLimit  = require('express-rate-limit');
const path       = require('path');
const fs         = require('fs');
const { setupDatabase } = require('./db/setup');

const app = express();

// Trust reverse proxy (Cloudflare / nginx) so rate limiting uses real client IP
app.set('trust proxy', 1);

// ── Security ──
app.use(helmet({
  hsts: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc:     ["'self'", "'unsafe-inline'", "https://static.cloudflareinsights.com"],
      scriptSrcAttr: ["'unsafe-inline'"],
      styleSrc:   ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      imgSrc:     ["'self'", "data:", "https:"],
      connectSrc: ["'self'"],
      fontSrc:    ["'self'", "https://fonts.gstatic.com"],
      objectSrc:  ["'none'"],
      frameSrc:   ["'none'"],
    },
  },
}));

app.use(cors({
  origin: process.env.CLIENT_URL || 'http://localhost:3000',
  credentials: true,
}));

app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

// Global rate limit
app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 300 }));

// ── API Routes ──
app.use('/api/auth', require('./routes/auth'));
app.use('/api/auth/oidc', require('./routes/oidc'));
app.use('/api/games', require('./routes/games'));
app.use('/api/rawg', require('./routes/rawg'));
app.use('/api/settings', require('./routes/settings'));
app.use('/api/admin', require('./routes/admin'));

// ── Health check ──
app.get('/api/health', (req, res) => res.json({ status: 'ok', ts: new Date().toISOString() }));

// ── Serve frontend in production ──
const clientPath = path.join(__dirname, '../client');
app.use(express.static(clientPath, { index: false }));

function isOidcReady() {
  return !!(process.env.OIDC_ENABLED === 'true' &&
    process.env.OIDC_ISSUER_URL && process.env.OIDC_CLIENT_ID &&
    process.env.OIDC_CLIENT_SECRET && process.env.OIDC_CALLBACK_URL);
}

app.get('*', (req, res) => {
  const indexPath = path.join(clientPath, 'index.html');
  let html = fs.readFileSync(indexPath, 'utf8');
  // Inject OIDC config as a synchronous global before any other script runs
  const oidcConfig = JSON.stringify({
    enabled: isOidcReady(),
    displayName: process.env.OIDC_DISPLAY_NAME || 'SSO',
  });
  html = html.replace('<head>', `<head><script>window.__OIDC__=${oidcConfig};</script>`);
  res.setHeader('Content-Type', 'text/html');
  res.send(html);
});

// ── Start ──
const PORT = process.env.PORT || 3000;

async function start() {
  await setupDatabase();
  app.listen(PORT, () => {
    console.log(`\n🎮  GameVault running at http://localhost:${PORT}`);
    console.log(`📡  API available at http://localhost:${PORT}/api\n`);
  });
}

start().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});

module.exports = app;
