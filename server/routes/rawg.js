const router = require('express').Router();
const fetch  = require('node-fetch');
const { requireAuth } = require('../middleware/auth');
const rateLimit = require('express-rate-limit');

const searchLimiter = rateLimit({ windowMs: 60 * 1000, max: 30, message: { error: 'Too many search requests' } });

const RAWG = 'https://api.rawg.io/api';

function rawgKey() {
  return process.env.RAWG_API_KEY || '';
}

// Normalise RAWG game into our format
function normaliseGame(g) {
  const platform = g.platforms?.[0]?.platform?.name || null;
  const genre    = g.genres?.[0]?.name || null;
  const year     = g.released ? g.released.slice(0, 4) : null;
  return {
    rawg_id:        g.id,
    rawg_slug:      g.slug,
    title:          g.name,
    art_url:        g.background_image || null,
    background_url: g.background_image_additional || g.background_image || null,
    platform,
    genre,
    year,
    metacritic:     g.metacritic || null,
    developer:      g.developers?.[0]?.name || null,
    publisher:      g.publishers?.[0]?.name || null,
    platforms_all:  g.platforms?.map(p => p.platform.name) || [],
    genres_all:     g.genres?.map(g2 => g2.name) || [],
    description:    g.description_raw || null,
    website:        g.website || null,
    playtime:       g.playtime || null,
    rawg_rating:    g.rating || null,
    rawg_rating_top: g.rating_top || null,
    esrb:           g.esrb_rating?.name || null,
    screenshots:    g.short_screenshots?.map(s => s.image) || [],
  };
}

// ── GET /rawg/search?q=elden+ring ──
router.get('/search', requireAuth, searchLimiter, async (req, res) => {
  try {
    const { q } = req.query;
    if (!q || q.length < 2) return res.status(400).json({ error: 'Query must be at least 2 characters' });
    const page      = Math.max(1, parseInt(req.query.page) || 1);
    const page_size = Math.min(20, Math.max(1, parseInt(req.query.page_size) || 10));

    const url = `${RAWG}/games?key=${rawgKey()}&search=${encodeURIComponent(q)}&page=${page}&page_size=${page_size}&search_precise=true`;
    const resp = await fetch(url);
    if (!resp.ok) throw new Error(`RAWG responded with ${resp.status}`);
    const data = await resp.json();

    res.json({
      count:   data.count,
      next:    data.next,
      results: (data.results || []).map(g => ({
        rawg_id:    g.id,
        rawg_slug:  g.slug,
        title:      g.name,
        art_url:    g.background_image,
        year:       g.released?.slice(0, 4) || null,
        platforms:  g.platforms?.map(p => p.platform.name) || [],
        genres:     g.genres?.map(x => x.name) || [],
        metacritic: g.metacritic || null,
        rating:     g.rating,
      }))
    });
  } catch (err) {
    console.error('RAWG search error:', err);
    res.status(502).json({ error: 'Game search failed. Check your RAWG API key.' });
  }
});

// ── GET /rawg/game/:idOrSlug — full details ──
router.get('/game/:idOrSlug', requireAuth, searchLimiter, async (req, res) => {
  try {
    const { idOrSlug } = req.params;
    if (!/^[a-zA-Z0-9_-]+$/.test(idOrSlug))
      return res.status(400).json({ error: 'Invalid game identifier' });
    const url = `${RAWG}/games/${idOrSlug}?key=${rawgKey()}`;
    const resp = await fetch(url);
    if (resp.status === 404) return res.status(404).json({ error: 'Game not found on RAWG' });
    if (!resp.ok) throw new Error(`RAWG responded with ${resp.status}`);
    const data = await resp.json();
    res.json(normaliseGame(data));
  } catch (err) {
    console.error('RAWG game detail error:', err);
    res.status(502).json({ error: 'Failed to fetch game details' });
  }
});

// ── GET /rawg/game/:idOrSlug/screenshots ──
router.get('/game/:idOrSlug/screenshots', requireAuth, searchLimiter, async (req, res) => {
  try {
    if (!/^[a-zA-Z0-9_-]+$/.test(req.params.idOrSlug))
      return res.status(400).json({ error: 'Invalid game identifier' });
    const url = `${RAWG}/games/${req.params.idOrSlug}/screenshots?key=${rawgKey()}&page_size=10`;
    const resp = await fetch(url);
    if (!resp.ok) throw new Error(`RAWG responded with ${resp.status}`);
    const data = await resp.json();
    res.json((data.results || []).map(s => s.image));
  } catch (err) {
    res.status(502).json({ error: 'Failed to fetch screenshots' });
  }
});

module.exports = router;
