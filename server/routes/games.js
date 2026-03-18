const router = require('express').Router();
const { pool } = require('../db/setup');
const { requireAuth } = require('../middleware/auth');

// All routes require auth
router.use(requireAuth);

// ── GET /games — list user's games ──
router.get('/', async (req, res) => {
  try {
    const { status, sort = 'updated_at', order = 'desc', search } = req.query;
    const params = [req.user.id];
    let where = 'WHERE user_id = $1';
    if (status) { params.push(status); where += ` AND status = $${params.length}`; }
    if (search) { params.push(`%${search}%`); where += ` AND (title ILIKE $${params.length} OR platform ILIKE $${params.length})`; }

    const allowed = { updated_at:1, created_at:1, title:1, rating:1, hours:1 };
    const col = allowed[sort] ? sort : 'updated_at';
    const dir = order === 'asc' ? 'ASC' : 'DESC';

    const { rows } = await pool.query(
      `SELECT * FROM games ${where} ORDER BY ${col} ${dir}`, params
    );
    res.json(rows);
  } catch (err) {
    console.error('Get games error:', err);
    res.status(500).json({ error: 'Failed to fetch games' });
  }
});

// ── GET /games/:id ──
router.get('/:id', async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM games WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]
  );
  if (!rows.length) return res.status(404).json({ error: 'Game not found' });
  res.json(rows[0]);
});

// ── POST /games — add game ──
router.post('/', async (req, res) => {
  try {
    const {
      rawg_id, title, status = 'toplay', rating = 0, hours = 0, review,
      platform, genre, year, art_url, background_url, developer, publisher,
      metacritic, rawg_slug, notes, completed_at
    } = req.body;
    if (!title) return res.status(400).json({ error: 'title is required' });
    if (!['playing','played','toplay'].includes(status))
      return res.status(400).json({ error: 'Invalid status' });
    if (rating !== undefined && (rating < 0 || rating > 5))
      return res.status(400).json({ error: 'Rating must be between 0 and 5' });
    if (hours !== undefined && hours < 0)
      return res.status(400).json({ error: 'Hours cannot be negative' });

    const resolvedCompletedAt = status === 'played'
      ? (completed_at || new Date().toISOString())
      : null;

    const { rows } = await pool.query(
      `INSERT INTO games (user_id, rawg_id, title, status, rating, hours, review,
        platform, genre, year, art_url, background_url, developer, publisher,
        metacritic, rawg_slug, notes, completed_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
       RETURNING *`,
      [req.user.id, rawg_id||null, title, status, rating||0, hours||0, review||null,
       platform||null, genre||null, year||null, art_url||null, background_url||null,
       developer||null, publisher||null, metacritic||null, rawg_slug||null, notes||null,
       resolvedCompletedAt]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'This game is already in your library' });
    console.error('Add game error:', err);
    res.status(500).json({ error: 'Failed to add game' });
  }
});

// ── PATCH /games/:id ──
router.patch('/:id', async (req, res) => {
  try {
    const existing = await pool.query(
      'SELECT * FROM games WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]
    );
    if (!existing.rows.length) return res.status(404).json({ error: 'Game not found' });

    if (req.body.status && !['playing','played','toplay'].includes(req.body.status))
      return res.status(400).json({ error: 'Invalid status' });
    if (req.body.rating !== undefined && (req.body.rating < 0 || req.body.rating > 5))
      return res.status(400).json({ error: 'Rating must be between 0 and 5' });
    if (req.body.hours !== undefined && req.body.hours < 0)
      return res.status(400).json({ error: 'Hours cannot be negative' });

    const fields = ['status','rating','hours','review','platform','genre','year',
                    'art_url','background_url','developer','publisher','metacritic','notes','title','completed_at'];

    // Auto-set completed_at when marking as played, clear it when moving to other statuses
    if (req.body.status === 'played' && !req.body.completed_at) {
      req.body.completed_at = existing.rows[0].completed_at || new Date().toISOString();
    } else if (req.body.status && req.body.status !== 'played') {
      req.body.completed_at = null;
    }
    const updates = [];
    const params = [];
    fields.forEach(f => {
      if (req.body[f] !== undefined) {
        params.push(req.body[f]);
        updates.push(`${f} = $${params.length}`);
      }
    });
    if (!updates.length) return res.status(400).json({ error: 'No fields to update' });

    params.push(req.params.id, req.user.id);
    const { rows } = await pool.query(
      `UPDATE games SET ${updates.join(', ')}, updated_at = NOW()
       WHERE id = $${params.length - 1} AND user_id = $${params.length} RETURNING *`,
      params
    );
    res.json(rows[0]);
  } catch (err) {
    console.error('Update game error:', err);
    res.status(500).json({ error: 'Failed to update game' });
  }
});

// ── DELETE /games/:id ──
router.delete('/:id', async (req, res) => {
  const { rowCount } = await pool.query(
    'DELETE FROM games WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]
  );
  if (!rowCount) return res.status(404).json({ error: 'Game not found' });
  res.json({ deleted: true });
});

// ── GET /games/stats/summary — dashboard stats ──
router.get('/stats/summary', async (req, res) => {
  try {
    const userId = req.user.id;
    const [counts, hours, topPlats, topGenres, recentActivity] = await Promise.all([
      pool.query(`SELECT status, COUNT(*) as count FROM games WHERE user_id=$1 GROUP BY status`, [userId]),
      pool.query(`SELECT SUM(hours) as total, AVG(hours) FILTER (WHERE hours > 0) as avg,
                         AVG(rating) FILTER (WHERE rating > 0) as avg_rating FROM games WHERE user_id=$1`, [userId]),
      pool.query(`SELECT platform, SUM(hours) as hours, COUNT(*) as count
                  FROM games WHERE user_id=$1 AND platform IS NOT NULL
                  GROUP BY platform ORDER BY hours DESC LIMIT 8`, [userId]),
      pool.query(`SELECT genre, COUNT(*) as count FROM games WHERE user_id=$1 AND genre IS NOT NULL
                  GROUP BY genre ORDER BY count DESC LIMIT 6`, [userId]),
      pool.query(`SELECT * FROM games WHERE user_id=$1 ORDER BY updated_at DESC LIMIT 5`, [userId]),
    ]);

    const countMap = {};
    counts.rows.forEach(r => { countMap[r.status] = parseInt(r.count); });
    const h = hours.rows[0];

    res.json({
      total:    (countMap.playing||0) + (countMap.played||0) + (countMap.toplay||0),
      playing:  countMap.playing  || 0,
      played:   countMap.played   || 0,
      toplay:   countMap.toplay   || 0,
      totalHours:  parseFloat(h.total||0).toFixed(1),
      avgHours:    parseFloat(h.avg||0).toFixed(1),
      avgRating:   parseFloat(h.avg_rating||0).toFixed(2),
      platformBreakdown: topPlats.rows,
      genreBreakdown:    topGenres.rows,
      recentActivity:    recentActivity.rows,
    });
  } catch (err) {
    console.error('Stats error:', err);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

module.exports = router;
