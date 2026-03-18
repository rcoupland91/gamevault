require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });
const { Pool } = require('pg');

const pool = new Pool({
  host:     process.env.DB_HOST     || 'localhost',
  port:     parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME     || 'gamevault',
  user:     process.env.DB_USER     || 'postgres',
  password: process.env.DB_PASSWORD || '',
  ssl: false,
});

const SCHEMA = `
-- Users
CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username      VARCHAR(50)  UNIQUE NOT NULL,
  email         VARCHAR(255) UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  avatar_url    TEXT,
  is_admin      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Add is_admin to existing deployments
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;

-- 2FA settings per user
CREATE TABLE IF NOT EXISTS user_2fa (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  totp_secret     TEXT,
  totp_enabled    BOOLEAN DEFAULT FALSE,
  email_otp_enabled BOOLEAN DEFAULT FALSE,
  backup_codes    TEXT[],
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Refresh tokens
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  token      TEXT UNIQUE NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Email OTP codes
CREATE TABLE IF NOT EXISTS otp_codes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  code       VARCHAR(6) NOT NULL,
  purpose    VARCHAR(20) NOT NULL,  -- 'login_2fa', 'verify_email', 'reset_password'
  expires_at TIMESTAMPTZ NOT NULL,
  used       BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Games library (per user)
CREATE TABLE IF NOT EXISTS games (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  rawg_id     INTEGER,
  title       VARCHAR(500) NOT NULL,
  status      VARCHAR(20) NOT NULL CHECK (status IN ('playing','played','toplay')),
  rating      SMALLINT CHECK (rating BETWEEN 0 AND 5),
  hours       NUMERIC(7,1) DEFAULT 0,
  review      TEXT,
  platform    VARCHAR(100),
  genre       VARCHAR(100),
  year        VARCHAR(4),
  art_url     TEXT,
  background_url TEXT,
  developer   VARCHAR(200),
  publisher   VARCHAR(200),
  metacritic  SMALLINT,
  rawg_slug   VARCHAR(300),
  notes       TEXT,
  completed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Add completed_at to existing deployments
ALTER TABLE games ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- App settings (server-wide)
CREATE TABLE IF NOT EXISTS app_settings (
  key   VARCHAR(100) PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default settings
INSERT INTO app_settings (key, value) VALUES ('signups_enabled', 'true') ON CONFLICT (key) DO NOTHING;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_games_user_id ON games(user_id);
CREATE INDEX IF NOT EXISTS idx_games_status  ON games(user_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_rawg ON games(user_id, rawg_id) WHERE rawg_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_otp_user ON otp_codes(user_id);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS users_updated_at ON users;
CREATE TRIGGER users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS games_updated_at ON games;
CREATE TRIGGER games_updated_at BEFORE UPDATE ON games FOR EACH ROW EXECUTE FUNCTION update_updated_at();
`;

async function setupDatabase() {
  const client = await pool.connect();
  try {
    console.log('🗄️  Setting up database schema…');
    await client.query(SCHEMA);
    console.log('✅  Database schema ready');
    await seedAdmin();
  } catch (err) {
    console.error('❌  Database setup failed:', err.message);
    process.exit(1);
  } finally {
    client.release();
  }
}

async function seedAdmin() {
  const { rows } = await pool.query('SELECT id FROM users WHERE is_admin = TRUE LIMIT 1');
  if (rows.length) return; // Admin already exists

  const username = process.env.ADMIN_USERNAME;
  const email    = process.env.ADMIN_EMAIL;
  const password = process.env.ADMIN_PASSWORD;

  if (!username || !email || !password) {
    console.warn('⚠️   No admin account found. Set ADMIN_USERNAME, ADMIN_EMAIL, ADMIN_PASSWORD in .env to create one on startup.');
    return;
  }

  const bcrypt = require('bcryptjs');
  const hash = await bcrypt.hash(password, 12);

  const client = await pool.connect();
  try {
    const { rows: inserted } = await client.query(
      `INSERT INTO users (username, email, password_hash, is_admin)
       VALUES ($1, $2, $3, TRUE)
       ON CONFLICT (email) DO UPDATE SET is_admin = TRUE
       RETURNING username, email`,
      [username.toLowerCase(), email.toLowerCase(), hash]
    );
    await client.query('INSERT INTO user_2fa (user_id) SELECT id FROM users WHERE email = $1 ON CONFLICT DO NOTHING', [email.toLowerCase()]);
    console.log(`✅  Admin account ready: ${inserted[0].username} (${inserted[0].email})`);
  } finally {
    client.release();
  }
}

if (require.main === module) {
  setupDatabase().then(() => pool.end());
}

module.exports = { pool, setupDatabase, seedAdmin };
