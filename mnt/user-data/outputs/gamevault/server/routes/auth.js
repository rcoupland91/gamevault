const router   = require('express').Router();
const bcrypt   = require('bcryptjs');
const speakeasy = require('speakeasy');
const QRCode   = require('qrcode');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../db/setup');
const { issueTokens, requireAuth } = require('../middleware/auth');
const { sendOTPEmail } = require('../utils/email');
const rateLimit = require('express-rate-limit');

const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 20, message: { error: 'Too many attempts, try again later' } });
const otpLimiter  = rateLimit({ windowMs: 5  * 60 * 1000, max: 5,  message: { error: 'Too many OTP attempts' } });

// ── Register ──
router.post('/register', authLimiter, async (req, res) => {
  try {
    const { username, email, password } = req.body;
    if (!username || !email || !password)
      return res.status(400).json({ error: 'username, email, and password required' });
    if (password.length < 8)
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    if (!/^[a-zA-Z0-9_]{3,30}$/.test(username))
      return res.status(400).json({ error: 'Username must be 3-30 alphanumeric characters or underscores' });

    const hash = await bcrypt.hash(password, 12);
    const { rows } = await pool.query(
      `INSERT INTO users (username, email, password_hash)
       VALUES ($1, $2, $3) RETURNING id, username, email, created_at`,
      [username.toLowerCase(), email.toLowerCase(), hash]
    );
    const user = rows[0];
    // Create blank 2FA record
    await pool.query('INSERT INTO user_2fa (user_id) VALUES ($1)', [user.id]);

    const tokens = issueTokens(user.id);
    await storeRefreshToken(user.id, tokens.refresh);

    res.status(201).json({ user: { id: user.id, username: user.username, email: user.email }, ...tokens });
  } catch (err) {
    if (err.code === '23505') {
      const field = err.detail?.includes('email') ? 'email' : 'username';
      return res.status(409).json({ error: `That ${field} is already taken` });
    }
    console.error('Register error:', err);
    res.status(500).json({ error: 'Registration failed' });
  }
});

// ── Login ──
router.post('/login', authLimiter, async (req, res) => {
  try {
    const { login, password } = req.body; // login = username or email
    if (!login || !password) return res.status(400).json({ error: 'login and password required' });

    const { rows } = await pool.query(
      `SELECT u.*, f.totp_enabled, f.email_otp_enabled
       FROM users u LEFT JOIN user_2fa f ON f.user_id = u.id
       WHERE u.email = $1 OR u.username = $1`,
      [login.toLowerCase()]
    );
    if (!rows.length) return res.status(401).json({ error: 'Invalid credentials' });

    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) return res.status(401).json({ error: 'Invalid credentials' });

    // Check if 2FA is required
    const needs2FA = user.totp_enabled || user.email_otp_enabled;
    if (needs2FA) {
      // Issue a short-lived pre-auth token
      const preToken = require('jsonwebtoken').sign(
        { sub: user.id, type: 'pre_auth', totp: user.totp_enabled, email_otp: user.email_otp_enabled },
        process.env.JWT_SECRET, { expiresIn: '10m' }
      );

      // If email OTP enabled, send code now
      if (user.email_otp_enabled) {
        await sendEmailOTP(user.id, user.email, user.username, 'login_2fa');
      }

      return res.json({
        requires2FA: true,
        preToken,
        methods: { totp: user.totp_enabled, email: user.email_otp_enabled }
      });
    }

    // No 2FA — issue full tokens
    const tokens = issueTokens(user.id);
    await storeRefreshToken(user.id, tokens.refresh);
    res.json({ user: sanitizeUser(user), ...tokens });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Login failed' });
  }
});

// ── Verify 2FA (TOTP or Email OTP) ──
router.post('/2fa/verify', otpLimiter, async (req, res) => {
  try {
    const { preToken, code, method } = req.body; // method: 'totp' | 'email'
    if (!preToken || !code) return res.status(400).json({ error: 'preToken and code required' });

    const jwt = require('jsonwebtoken');
    let payload;
    try { payload = jwt.verify(preToken, process.env.JWT_SECRET); }
    catch { return res.status(401).json({ error: 'Invalid or expired pre-auth token' }); }
    if (payload.type !== 'pre_auth') return res.status(401).json({ error: 'Invalid token type' });

    const { rows } = await pool.query('SELECT * FROM user_2fa WHERE user_id = $1', [payload.sub]);
    const tfa = rows[0];
    const { rows: userRows } = await pool.query('SELECT * FROM users WHERE id = $1', [payload.sub]);
    const user = userRows[0];

    let valid = false;

    if (method === 'totp' && tfa?.totp_enabled) {
      valid = speakeasy.totp.verify({
        secret:   tfa.totp_secret,
        encoding: 'base32',
        token:    code,
        window:   2,
      });
    } else if (method === 'email') {
      const { rows: otpRows } = await pool.query(
        `SELECT * FROM otp_codes WHERE user_id = $1 AND purpose = 'login_2fa' AND used = FALSE AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1`,
        [payload.sub]
      );
      if (otpRows.length && otpRows[0].code === code) {
        valid = true;
        await pool.query('UPDATE otp_codes SET used = TRUE WHERE id = $1', [otpRows[0].id]);
      }
    }

    if (!valid) return res.status(401).json({ error: 'Invalid or expired code' });

    const tokens = issueTokens(user.id);
    await storeRefreshToken(user.id, tokens.refresh);
    res.json({ user: sanitizeUser(user), ...tokens });
  } catch (err) {
    console.error('2FA verify error:', err);
    res.status(500).json({ error: '2FA verification failed' });
  }
});

// ── Resend email OTP ──
router.post('/2fa/resend', otpLimiter, async (req, res) => {
  try {
    const { preToken } = req.body;
    const jwt = require('jsonwebtoken');
    const payload = jwt.verify(preToken, process.env.JWT_SECRET);
    if (payload.type !== 'pre_auth') return res.status(401).json({ error: 'Invalid token' });
    const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [payload.sub]);
    await sendEmailOTP(payload.sub, rows[0].email, rows[0].username, 'login_2fa');
    res.json({ message: 'OTP sent' });
  } catch { res.status(400).json({ error: 'Failed to resend OTP' }); }
});

// ── Setup TOTP (get QR code) ──
router.post('/2fa/totp/setup', requireAuth, async (req, res) => {
  try {
    const secret = speakeasy.generateSecret({
      name:   `${process.env.TOTP_APP_NAME || 'GameVault'} (${req.user.email})`,
      length: 32,
    });
    // Store secret (not yet enabled — user must verify first)
    await pool.query(
      `UPDATE user_2fa SET totp_secret = $1 WHERE user_id = $2`,
      [secret.base32, req.user.id]
    );
    const qrDataUrl = await QRCode.toDataURL(secret.otpauth_url);
    res.json({ secret: secret.base32, qrCode: qrDataUrl, otpauthUrl: secret.otpauth_url });
  } catch (err) {
    console.error('TOTP setup error:', err);
    res.status(500).json({ error: 'TOTP setup failed' });
  }
});

// ── Confirm TOTP (enable it) ──
router.post('/2fa/totp/confirm', requireAuth, async (req, res) => {
  try {
    const { code } = req.body;
    const { rows } = await pool.query('SELECT * FROM user_2fa WHERE user_id = $1', [req.user.id]);
    const tfa = rows[0];
    if (!tfa?.totp_secret) return res.status(400).json({ error: 'TOTP not set up yet' });

    const valid = speakeasy.totp.verify({ secret: tfa.totp_secret, encoding: 'base32', token: code, window: 2 });
    if (!valid) return res.status(401).json({ error: 'Invalid code — check your authenticator app' });

    // Generate backup codes
    const backupCodes = Array.from({ length: 8 }, () =>
      Math.random().toString(36).slice(2, 6).toUpperCase() + '-' + Math.random().toString(36).slice(2, 6).toUpperCase()
    );
    const hashed = await Promise.all(backupCodes.map(c => bcrypt.hash(c, 10)));

    await pool.query(
      `UPDATE user_2fa SET totp_enabled = TRUE, backup_codes = $1 WHERE user_id = $2`,
      [hashed, req.user.id]
    );
    res.json({ enabled: true, backupCodes }); // Show backup codes ONCE
  } catch (err) {
    console.error('TOTP confirm error:', err);
    res.status(500).json({ error: 'TOTP confirmation failed' });
  }
});

// ── Enable/disable email OTP ──
router.post('/2fa/email/toggle', requireAuth, async (req, res) => {
  try {
    const { enabled } = req.body;
    await pool.query('UPDATE user_2fa SET email_otp_enabled = $1 WHERE user_id = $2', [!!enabled, req.user.id]);
    res.json({ emailOtpEnabled: !!enabled });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update email OTP setting' });
  }
});

// ── Disable TOTP ──
router.post('/2fa/totp/disable', requireAuth, async (req, res) => {
  try {
    const { code } = req.body;
    const { rows } = await pool.query('SELECT * FROM user_2fa WHERE user_id = $1', [req.user.id]);
    const valid = speakeasy.totp.verify({ secret: rows[0]?.totp_secret, encoding: 'base32', token: code, window: 2 });
    if (!valid) return res.status(401).json({ error: 'Invalid code' });
    await pool.query('UPDATE user_2fa SET totp_enabled = FALSE, totp_secret = NULL WHERE user_id = $1', [req.user.id]);
    res.json({ disabled: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to disable TOTP' });
  }
});

// ── Get 2FA status ──
router.get('/2fa/status', requireAuth, async (req, res) => {
  const { rows } = await pool.query('SELECT totp_enabled, email_otp_enabled FROM user_2fa WHERE user_id = $1', [req.user.id]);
  res.json(rows[0] || { totp_enabled: false, email_otp_enabled: false });
});

// ── Refresh token ──
router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(400).json({ error: 'refreshToken required' });

    const jwt = require('jsonwebtoken');
    const payload = jwt.verify(refreshToken, process.env.REFRESH_TOKEN_SECRET);
    if (payload.type !== 'refresh') return res.status(401).json({ error: 'Invalid token type' });

    // Check token is in DB and not expired
    const { rows } = await pool.query(
      'SELECT * FROM refresh_tokens WHERE token = $1 AND expires_at > NOW()', [refreshToken]
    );
    if (!rows.length) return res.status(401).json({ error: 'Invalid or expired refresh token' });

    // Rotate refresh token
    await pool.query('DELETE FROM refresh_tokens WHERE token = $1', [refreshToken]);
    const tokens = issueTokens(payload.sub);
    await storeRefreshToken(payload.sub, tokens.refresh);

    const { rows: userRows } = await pool.query('SELECT id, username, email FROM users WHERE id = $1', [payload.sub]);
    res.json({ user: userRows[0], ...tokens });
  } catch (err) {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});

// ── Logout ──
router.post('/logout', requireAuth, async (req, res) => {
  const { refreshToken } = req.body;
  if (refreshToken) await pool.query('DELETE FROM refresh_tokens WHERE token = $1', [refreshToken]);
  res.json({ message: 'Logged out' });
});

// ── Get current user ──
router.get('/me', requireAuth, async (req, res) => {
  const { rows } = await pool.query(
    `SELECT u.id, u.username, u.email, u.avatar_url, u.created_at,
            f.totp_enabled, f.email_otp_enabled
     FROM users u LEFT JOIN user_2fa f ON f.user_id = u.id WHERE u.id = $1`,
    [req.user.id]
  );
  res.json(rows[0]);
});

// ── Helpers ──
async function storeRefreshToken(userId, token) {
  const expires = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  await pool.query('INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)', [userId, token, expires]);
  // Clean up old tokens for this user (keep last 5)
  await pool.query(`
    DELETE FROM refresh_tokens WHERE user_id = $1 AND id NOT IN (
      SELECT id FROM refresh_tokens WHERE user_id = $1 ORDER BY created_at DESC LIMIT 5
    )`, [userId]);
}

async function sendEmailOTP(userId, email, username, purpose) {
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expires = new Date(Date.now() + 10 * 60 * 1000);
  // Invalidate previous codes
  await pool.query(`UPDATE otp_codes SET used = TRUE WHERE user_id = $1 AND purpose = $2 AND used = FALSE`, [userId, purpose]);
  await pool.query(`INSERT INTO otp_codes (user_id, code, purpose, expires_at) VALUES ($1, $2, $3, $4)`, [userId, code, purpose, expires]);
  await sendOTPEmail(email, username, code, purpose);
}

function sanitizeUser(u) {
  return { id: u.id, username: u.username, email: u.email, avatar_url: u.avatar_url, created_at: u.created_at };
}

module.exports = router;
