const router = require('express').Router();
const { pool } = require('../db/setup');
const { requireAuth, requireAdmin } = require('../middleware/auth');

// ── GET /settings/public — public settings (no auth needed) ──
router.get('/public', async (req, res) => {
  try {
    const { rows } = await pool.query(
      "SELECT key, value FROM app_settings WHERE key IN ('signups_enabled', 'oidc_enabled', 'oidc_display_name')"
    );
    const s = {};
    rows.forEach(r => { s[r.key] = r.value; });

    // OIDC is active only when the env var is set AND the DB flag is enabled
    const oidcEnvReady = !!(process.env.OIDC_ENABLED === 'true' &&
      process.env.OIDC_ISSUER_URL &&
      process.env.OIDC_CLIENT_ID &&
      process.env.OIDC_CLIENT_SECRET &&
      process.env.OIDC_CALLBACK_URL);

    res.json({
      signups_enabled: s.signups_enabled !== 'false',
      oidc_enabled: oidcEnvReady && s.oidc_enabled === 'true',
      oidc_display_name: s.oidc_display_name || 'SSO',
    });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch settings' });
  }
});

// ── GET /settings — all settings (auth required) ──
router.get('/', requireAuth, async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT key, value FROM app_settings');
    const settings = {};
    rows.forEach(r => { settings[r.key] = r.value; });
    res.json(settings);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch settings' });
  }
});

// ── PATCH /settings — update a setting (admin only) ──
router.patch('/', requireAuth, requireAdmin, async (req, res) => {
  try {
    const { key, value } = req.body;
    const allowed = ['signups_enabled', 'oidc_enabled', 'oidc_display_name'];
    if (!allowed.includes(key))
      return res.status(400).json({ error: 'Unknown setting' });

    await pool.query(
      `INSERT INTO app_settings (key, value, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
      [key, String(value)]
    );
    res.json({ key, value: String(value) });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update setting' });
  }
});

module.exports = router;
