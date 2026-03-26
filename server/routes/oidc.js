const crypto = require('crypto');
const router = require('express').Router();
const { pool } = require('../db/setup');
const { issueTokens } = require('../middleware/auth');

// Lazy-loaded OIDC client (initialized on first use)
let oidcClient = null;

// In-memory state store for CSRF protection (state -> { nonce, createdAt })
const stateMap = new Map();

// Purge states older than 10 minutes
setInterval(() => {
  const cutoff = Date.now() - 10 * 60 * 1000;
  for (const [state, data] of stateMap.entries()) {
    if (data.createdAt < cutoff) stateMap.delete(state);
  }
}, 5 * 60 * 1000);

function isOidcEnabled() {
  return process.env.OIDC_ENABLED === 'true' &&
    process.env.OIDC_ISSUER_URL &&
    process.env.OIDC_CLIENT_ID &&
    process.env.OIDC_CLIENT_SECRET &&
    process.env.OIDC_CALLBACK_URL;
}

async function getOidcClient() {
  if (oidcClient) return oidcClient;
  const { Issuer } = require('openid-client');
  const issuer = await Issuer.discover(process.env.OIDC_ISSUER_URL);
  oidcClient = new issuer.Client({
    client_id: process.env.OIDC_CLIENT_ID,
    client_secret: process.env.OIDC_CLIENT_SECRET,
    redirect_uris: [process.env.OIDC_CALLBACK_URL],
    response_types: ['code'],
  });
  return oidcClient;
}

async function storeRefreshToken(userId, token) {
  const expires = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  await pool.query('INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)', [userId, token, expires]);
  await pool.query(`
    DELETE FROM refresh_tokens WHERE user_id = $1 AND id NOT IN (
      SELECT id FROM refresh_tokens WHERE user_id = $1 ORDER BY created_at DESC LIMIT 5
    )`, [userId]);
}

// ── GET /auth/oidc/login — redirect to OIDC provider ──
router.get('/login', async (req, res) => {
  if (!isOidcEnabled()) {
    return res.status(404).json({ error: 'OIDC is not enabled' });
  }
  try {
    const client = await getOidcClient();
    const state = crypto.randomBytes(16).toString('hex');
    const nonce = crypto.randomBytes(16).toString('hex');
    stateMap.set(state, { nonce, createdAt: Date.now() });

    const authUrl = client.authorizationUrl({
      scope: 'openid email profile',
      state,
      nonce,
    });
    res.redirect(authUrl);
  } catch (err) {
    console.error('OIDC login error:', err);
    res.status(500).json({ error: 'OIDC configuration error: ' + err.message });
  }
});

// ── GET /auth/oidc/callback — handle provider callback ──
router.get('/callback', async (req, res) => {
  if (!isOidcEnabled()) {
    return res.status(404).json({ error: 'OIDC is not enabled' });
  }
  try {
    const client = await getOidcClient();
    const params = client.callbackParams(req);
    const stateData = stateMap.get(params.state);

    if (!stateData) {
      return res.redirect('gamevault://auth/error?message=Invalid+or+expired+state');
    }
    stateMap.delete(params.state);

    const tokenSet = await client.callback(process.env.OIDC_CALLBACK_URL, params, {
      state: params.state,
      nonce: stateData.nonce,
    });

    const claims = tokenSet.claims();
    const sub = claims.sub;
    const email = claims.email;

    if (!sub) {
      return res.redirect('gamevault://auth/error?message=Missing+user+identifier');
    }

    let userId;

    // Check for existing OAuth link
    const { rows: oauthRows } = await pool.query(
      'SELECT user_id FROM user_oauth WHERE provider = $1 AND subject = $2',
      ['oidc', sub]
    );

    if (oauthRows.length > 0) {
      userId = oauthRows[0].user_id;
    } else {
      // Try to link to existing account by email
      if (email) {
        const { rows: emailRows } = await pool.query(
          'SELECT id FROM users WHERE email = $1',
          [email.toLowerCase()]
        );
        if (emailRows.length > 0) {
          userId = emailRows[0].id;
          await pool.query(
            'INSERT INTO user_oauth (user_id, provider, subject, email) VALUES ($1, $2, $3, $4)',
            [userId, 'oidc', sub, email.toLowerCase()]
          );
        }
      }

      // Create new user if still no match
      if (!userId) {
        const rawUsername = claims.preferred_username ||
          (email ? email.split('@')[0] : null) ||
          `user_${sub.slice(0, 8)}`;

        let username = rawUsername.toLowerCase().replace(/[^a-z0-9_]/g, '_').slice(0, 30);
        if (username.length < 3) username = `user_${sub.slice(0, 8)}`;

        // Ensure username is unique
        let finalUsername = username;
        for (let i = 1; ; i++) {
          const { rows: taken } = await pool.query('SELECT id FROM users WHERE username = $1', [finalUsername]);
          if (taken.length === 0) break;
          finalUsername = `${username}_${i}`;
        }

        const userEmail = email ? email.toLowerCase() : `${sub}@oidc.local`;
        const { rows: newUser } = await pool.query(
          `INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3) RETURNING id`,
          [finalUsername, userEmail, crypto.randomBytes(32).toString('hex')]
        );
        userId = newUser[0].id;

        await pool.query('INSERT INTO user_2fa (user_id) VALUES ($1)', [userId]);
        await pool.query(
          'INSERT INTO user_oauth (user_id, provider, subject, email) VALUES ($1, $2, $3, $4)',
          [userId, 'oidc', sub, email ? email.toLowerCase() : null]
        );
      }
    }

    const tokens = issueTokens(userId);
    await storeRefreshToken(userId, tokens.refresh);

    const redirectUrl = `gamevault://auth/callback?access=${encodeURIComponent(tokens.access)}&refresh=${encodeURIComponent(tokens.refresh)}`;
    res.redirect(redirectUrl);
  } catch (err) {
    console.error('OIDC callback error:', err);
    const msg = encodeURIComponent(err.message || 'Authentication failed');
    res.redirect(`gamevault://auth/error?message=${msg}`);
  }
});

module.exports = router;
