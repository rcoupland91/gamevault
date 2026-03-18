const router = require('express').Router();
const { pool } = require('../db/setup');
const { requireAuth, requireAdmin } = require('../middleware/auth');

// All admin routes require auth + admin role
router.use(requireAuth, requireAdmin);

// ── GET /admin/users — list all users ──
router.get('/users', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, username, email, is_admin, is_active, created_at
       FROM users ORDER BY created_at ASC`
    );
    res.json(rows);
  } catch (err) {
    console.error('Admin list users error:', err);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// ── PATCH /admin/users/:id/role — promote or demote a user ──
router.patch('/users/:id/role', async (req, res) => {
  try {
    const { id } = req.params;
    const { is_admin } = req.body;

    if (typeof is_admin !== 'boolean')
      return res.status(400).json({ error: 'is_admin must be a boolean' });

    if (id === req.user.id && !is_admin)
      return res.status(400).json({ error: 'You cannot remove your own admin role' });

    const { rows } = await pool.query(
      `UPDATE users SET is_admin = $1 WHERE id = $2
       RETURNING id, username, email, is_admin`,
      [is_admin, id]
    );
    if (!rows.length) return res.status(404).json({ error: 'User not found' });

    res.json(rows[0]);
  } catch (err) {
    console.error('Admin role update error:', err);
    res.status(500).json({ error: 'Failed to update role' });
  }
});

// ── PATCH /admin/users/:id/status — enable or disable a user ──
router.patch('/users/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { is_active } = req.body;

    if (typeof is_active !== 'boolean')
      return res.status(400).json({ error: 'is_active must be a boolean' });

    if (id === req.user.id && !is_active)
      return res.status(400).json({ error: 'You cannot disable your own account' });

    const { rows } = await pool.query(
      `UPDATE users SET is_active = $1 WHERE id = $2
       RETURNING id, username, email, is_admin, is_active`,
      [is_active, id]
    );
    if (!rows.length) return res.status(404).json({ error: 'User not found' });

    res.json(rows[0]);
  } catch (err) {
    console.error('Admin status update error:', err);
    res.status(500).json({ error: 'Failed to update status' });
  }
});

// ── DELETE /admin/users/:id — delete a user ──
router.delete('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;

    if (id === req.user.id)
      return res.status(400).json({ error: 'You cannot delete your own account' });

    const { rowCount } = await pool.query('DELETE FROM users WHERE id = $1', [id]);
    if (!rowCount) return res.status(404).json({ error: 'User not found' });

    res.json({ deleted: true });
  } catch (err) {
    console.error('Admin delete user error:', err);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

module.exports = router;
