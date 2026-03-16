const router = require('express').Router();
const { pool } = require('../db/setup');
const { requireAuth, requireAdmin } = require('../middleware/auth');

// ── GET /settings/public — public settings (no auth needed) ──
router.get('/public', async (req, res) => {
  try {
    const { rows } = await pool.query(
      "SELECT key, value FROM app_settings WHERE key = 'signups_enabled'"
    );
    res.json({ signups_enabled: rows[0]?.value !== 'false' });
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
    const allowed = ['signups_enabled'];
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
