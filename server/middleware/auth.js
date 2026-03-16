const jwt = require('jsonwebtoken');
const { pool } = require('../db/setup');

// Verify JWT and attach user to req
async function requireAuth(req, res, next) {
  try {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }
    const token = header.slice(7);
    const payload = jwt.verify(token, process.env.JWT_SECRET);

    // Check user still exists
    const { rows } = await pool.query(
      'SELECT id, username, email, is_admin FROM users WHERE id = $1', [payload.sub]
    );
    if (!rows.length) return res.status(401).json({ error: 'User not found' });

    req.user = rows[0];
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// Issue access + refresh tokens
function issueTokens(userId) {
  const access = jwt.sign(
    { sub: userId, type: 'access' },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '15m' }
  );
  const refresh = jwt.sign(
    { sub: userId, type: 'refresh' },
    process.env.REFRESH_TOKEN_SECRET,
    { expiresIn: '30d' }
  );
  return { access, refresh };
}

function requireAdmin(req, res, next) {
  if (!req.user?.is_admin) return res.status(403).json({ error: 'Admin access required' });
  next();
}

module.exports = { requireAuth, requireAdmin, issueTokens };
