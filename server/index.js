require('dotenv').config();
const express    = require('express');
const cors       = require('cors');
const helmet     = require('helmet');
const rateLimit  = require('express-rate-limit');
const path       = require('path');
const { setupDatabase } = require('./db/setup');

const app = express();

// ── Security ──
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc:  ["'self'", "'unsafe-inline'", "https://static.cloudflareinsights.com"],
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

app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));

// Global rate limit
app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 300 }));

// ── API Routes ──
app.use('/api/auth', require('./routes/auth'));
app.use('/api/games', require('./routes/games'));
app.use('/api/rawg', require('./routes/rawg'));
app.use('/api/settings', require('./routes/settings'));
app.use('/api/admin', require('./routes/admin'));

// ── Health check ──
app.get('/api/health', (req, res) => res.json({ status: 'ok', ts: new Date().toISOString() }));

// ── Serve frontend in production ──
const clientPath = path.join(__dirname, '../client');
app.use(express.static(clientPath));
app.get('*', (req, res) => {
  res.sendFile(path.join(clientPath, 'index.html'));
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
