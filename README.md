# GameVault 🎮

> **Note:** This project was built with the assistance of AI (Claude by Anthropic). I'm a Cloud Engineer rather than a web developer — AI helped bridge that gap to bring this project to life.

A self-hosted game tracking app with user accounts, cross-device sync, 2FA, and automatic game data lookup via RAWG.io.

---

## Features

- ✅ Track **Now Playing**, **Completed**, and **Backlog**
- 🔍 Auto-fill game info (artwork, platform, genre, developer) from RAWG.io
- ⭐ 5-star rating system + full review/notes per game
- 📊 Dashboard with stats: hours played, platform breakdown, top rated
- 👤 User accounts — everyone gets their own separate library
- 🔐 Two-factor authentication — Authenticator app (TOTP) and/or Email OTP
- 🌙 Dark / Light mode
- 📱 PWA — installable on iPhone home screen
- 🔄 Cross-device sync via the backend API
- 🐳 Docker Compose setup — one command to run everything

---

## Hosting Philosophy

GameVault is designed for **self-hosting on your local network**, with external access via:

- **Cloudflare Tunnel** — exposes the app on your domain with HTTPS, no open router ports needed
- **Tailscale / WireGuard VPN** — access via VPN from anywhere, completely private

Because of this, **nginx is not included** — Cloudflare Tunnels and VPNs handle HTTPS and proxying for you. The app runs directly on a port and you point your tunnel or VPN at it.

---

## Quick Start (Docker)

This is the recommended way to run GameVault. You only need Docker installed — no Node.js or PostgreSQL required on the host.

### 1. Clone the repo

```bash
git clone https://github.com/yourusername/gamevault.git
cd gamevault
```

### 2. Configure environment

```bash
cp .env.example .env
```

Open `.env` and fill in your values. At minimum you need:

```env
DB_PASSWORD=choose_a_strong_password
JWT_SECRET=<long random string>
REFRESH_TOKEN_SECRET=<another long random string>

# Creates the first admin account on startup (only runs once, safe to remove after)
ADMIN_USERNAME=admin
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=choose_a_strong_password
```

Generate secure secrets with:

```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

Run it twice — use each output for `JWT_SECRET` and `REFRESH_TOKEN_SECRET`.

> **First run:** If `ADMIN_*` vars are set and no admin exists, the admin account is created automatically on startup. You can remove these vars from `.env` after the first run, or leave them — they are ignored once an admin already exists.

### 3. Start

```bash
docker compose up -d
```

Docker will pull Postgres, build the app, run the database schema setup, and start everything. The app is now at **http://your-server-ip:3000**.

---

## Accessing the App

### On your local network

Once running, any device on your home network can access GameVault at:

```
http://192.168.x.x:3000
```

Replace `192.168.x.x` with your server's local IP. You can find it with `ip addr` (Linux) or `ipconfig` (Windows).

To make it easier, set a static IP for your server in your router's DHCP settings.

---

### External access — Cloudflare Tunnel (recommended)

Cloudflare Tunnels give you HTTPS on your own domain with zero open ports on your router. Works even behind CGNAT.

1. Sign up at [cloudflare.com](https://cloudflare.com) (free) and add your domain
2. Install `cloudflared` on your server:

```bash
# Debian/Ubuntu
curl -L https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update && sudo apt install cloudflared
```

3. Authenticate and create a tunnel:

```bash
cloudflared tunnel login
cloudflared tunnel create gamevault
```

4. Create a config file at `~/.cloudflared/config.yml`:

```yaml
tunnel: <your-tunnel-id>
credentials-file: /home/youruser/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: gamevault.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
```

5. Route DNS and start:

```bash
cloudflared tunnel route dns gamevault gamevault.yourdomain.com
cloudflared tunnel run gamevault
```

6. To run as a background service:

```bash
sudo cloudflared service install
sudo systemctl start cloudflared
```

GameVault is now at `https://gamevault.yourdomain.com` with automatic HTTPS.

> **Tip:** Update `CLIENT_URL=https://gamevault.yourdomain.com` in your `.env` and restart with `docker compose up -d` after setting up the tunnel.

---

### External access — Tailscale VPN

Tailscale creates a private network between your devices. No ports open, no domain needed.

1. Install Tailscale on your server:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

2. Install Tailscale on your phone/laptop from [tailscale.com/download](https://tailscale.com/download)

3. Once connected, access GameVault at your server's Tailscale IP:

```
http://100.x.x.x:3000
```

Find your server's Tailscale IP with `tailscale ip -4`.

---

## Docker Commands

```bash
# Start in background
docker compose up -d

# View logs
docker compose logs -f

# View just app logs
docker compose logs -f app

# Stop
docker compose down

# Full reset (deletes database)
docker compose down -v

# Rebuild after code changes
docker compose up -d --build

# Open shell in app container
docker compose exec app sh

# Connect to Postgres directly
docker compose exec postgres psql -U gamevault -d gamevault
```

---

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DB_PASSWORD` | ✅ | — | PostgreSQL password |
| `DB_NAME` | | `gamevault` | Database name |
| `DB_USER` | | `gamevault` | Database user |
| `JWT_SECRET` | ✅ | — | Secret for signing access tokens |
| `REFRESH_TOKEN_SECRET` | ✅ | — | Secret for signing refresh tokens |
| `JWT_EXPIRES_IN` | | `15m` | Access token lifetime |
| `PORT` | | `3000` | Port the app listens on |
| `CLIENT_URL` | | `http://localhost:3000` | Your app's public URL (used in emails) |
| `ADMIN_USERNAME` | | — | Username for the initial admin account (first run only) |
| `ADMIN_EMAIL` | | — | Email for the initial admin account (first run only) |
| `ADMIN_PASSWORD` | | — | Password for the initial admin account (first run only) |
| `RAWG_API_KEY` | | — | Free key from [rawg.io/apidocs](https://rawg.io/apidocs) |
| `SMTP_HOST` | | — | SMTP server for email OTP |
| `SMTP_PORT` | | `587` | SMTP port |
| `SMTP_USER` | | — | SMTP username / email address |
| `SMTP_PASS` | | — | SMTP password / app password |
| `EMAIL_FROM` | | — | From address for OTP emails |
| `TOTP_APP_NAME` | | `GameVault` | Name shown in authenticator apps |

> **Email OTP** is optional — if SMTP is not configured, users can still use TOTP (authenticator app) for 2FA, or skip 2FA entirely.

> **Admin account** — The `ADMIN_*` vars are only used on the very first startup when no admin exists. They are ignored on all subsequent starts. You can remove them from `.env` after setup.

---

## Manual Setup (without Docker)

If you prefer to run without Docker:

### Prerequisites
- Node.js v20+
- PostgreSQL v14+

### Steps

```bash
# Install dependencies
npm install

# Create database
psql -U postgres -c "CREATE DATABASE gamevault;"

# Configure environment
cp .env.example .env
# Edit .env with your database credentials and secrets

# Run database migrations
npm run setup-db

# Start
npm start          # production
npm run dev        # development (auto-restart)
```

---

## API Reference

### Auth
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/auth/register` | — | Create account |
| POST | `/api/auth/login` | — | Sign in |
| POST | `/api/auth/2fa/verify` | — | Verify 2FA code |
| POST | `/api/auth/2fa/resend` | — | Resend email OTP |
| GET  | `/api/auth/me` | ✅ | Get current user (includes `is_admin`) |
| PATCH | `/api/auth/profile` | ✅ | Update username, avatar, password |
| POST | `/api/auth/refresh` | — | Refresh access token |
| POST | `/api/auth/logout` | ✅ | Sign out |

### 2FA
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET  | `/api/auth/2fa/status` | ✅ | Get 2FA settings |
| POST | `/api/auth/2fa/totp/setup` | ✅ | Get TOTP QR code |
| POST | `/api/auth/2fa/totp/confirm` | ✅ | Enable TOTP + get backup codes |
| POST | `/api/auth/2fa/totp/disable` | ✅ | Disable TOTP |
| POST | `/api/auth/2fa/email/toggle` | ✅ | Toggle email OTP |

### Games
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET    | `/api/games` | ✅ | List games (supports `?status=`, `?search=`, `?sort=`) |
| POST   | `/api/games` | ✅ | Add a game |
| GET    | `/api/games/:id` | ✅ | Get single game |
| PATCH  | `/api/games/:id` | ✅ | Update game |
| DELETE | `/api/games/:id` | ✅ | Delete game |
| GET    | `/api/games/stats/summary` | ✅ | Dashboard stats |

### RAWG Game Search
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/rawg/search?q=elden+ring` | ✅ | Search games |
| GET | `/api/rawg/game/:idOrSlug` | ✅ | Full game details |
| GET | `/api/rawg/game/:idOrSlug/screenshots` | ✅ | Screenshots |

### Settings
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET  | `/api/settings/public` | — | Public settings (signups enabled?) |
| GET  | `/api/settings` | ✅ | All settings |
| PATCH | `/api/settings` | ✅ Admin | Update a setting |

### Admin
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET   | `/api/admin/users` | ✅ Admin | List all users |
| PATCH | `/api/admin/users/:id/role` | ✅ Admin | Promote or demote admin (`{ "is_admin": true/false }`) |

---

## iPhone PWA

Once the app is accessible over HTTPS (via Cloudflare Tunnel or a domain):

1. Open the URL in **Safari** on iPhone
2. Tap **Share → Add to Home Screen**
3. GameVault launches as a full-screen app with offline support

> PWA install requires HTTPS. On your local network over HTTP it will work in the browser but won't install as a PWA.

---

## Security Notes

- JWT access tokens expire in 15 minutes; refresh tokens last 30 days and rotate on each use
- Passwords hashed with bcrypt (cost factor 12)
- Rate limiting on all auth endpoints
- OTP codes and TOTP backup codes generated with `crypto.randomBytes` / `crypto.randomInt` (cryptographically secure)
- OTP verification uses constant-time comparison (`crypto.timingSafeEqual`) to prevent timing attacks
- TOTP backup codes are bcrypt-hashed and shown to the user only once
- Each user can only access their own games — enforced at the database query level
- Postgres is on an internal Docker network, not reachable from outside the host
- Content Security Policy (CSP) enforced via Helmet — restricts script, style, font, and frame sources
- Admin-only routes protected by a separate `requireAdmin` middleware — role stored in the database
- Admin account seeded from environment variables on first startup; ignored on subsequent starts

---

## File Structure

```
gamevault/
├── server/
│   ├── index.js              ← Express entry point, CSP/security headers
│   ├── db/setup.js           ← PostgreSQL schema, connection pool, admin seed
│   ├── middleware/auth.js    ← JWT verification, requireAuth, requireAdmin
│   ├── routes/
│   │   ├── auth.js           ← Register, login, 2FA, profile
│   │   ├── games.js          ← Game CRUD + stats
│   │   ├── rawg.js           ← RAWG.io game search proxy
│   │   ├── settings.js       ← App settings (admin-protected writes)
│   │   └── admin.js          ← User management (admin only)
│   └── utils/email.js        ← OTP email sender
├── client/
│   ├── index.html            ← Full frontend SPA
│   ├── manifest.json         ← PWA manifest
│   └── sw.js                 ← Service worker (offline support)
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── .gitignore
└── .dockerignore
```
