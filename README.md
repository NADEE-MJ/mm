# MacMiniServer Quickstart

Services running on the Mac Mini, replacing the Debian `maida-server`.

## Architecture

```
Internet → Cloudflare → Mac Mini nginx (SSL terminator)
                              ├── mm.nadee-mj.dev      → localhost:8155
                              ├── raddle.nadee-mj.dev  → localhost:8000
                              ├── jeopardy.nadee-mj.dev → localhost:3000
                              ├── jelly.nadee-mj.dev   → 192.168.1.42:8096  (Debian)
                              ├── vault.nadee-mj.dev   → 192.168.1.42:8080  (Debian)
                              ├── hass.nadee-mj.dev    → 192.168.1.42:8123  (Debian)
                              └── abs.nadee-mj.dev     → 192.168.1.42:13378 (Debian)
```

## Prerequisites

Install via Homebrew:

```sh
brew install nginx gh uv python3
```

Install nvm (for Node.js services):

```sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
```

## One-time setup

### 1. `/opt/projects`

```sh
sudo mkdir /opt/projects
sudo chown nadeem /opt/projects
```

### 2. SSL keys

Place your Cloudflare origin certificates in `nginx/keys/` (gitignored):

```sh
mkdir -p /Users/nadeem/Documents/MacMiniServer/nginx/keys
# Copy cloudflare.pem and cloudflare.key here
```

### 3. nginx

```sh
cd /Users/nadeem/Documents/MacMiniServer/nginx
bash setup.sh
```

This symlinks `nginx/nginx.conf` to `/opt/homebrew/etc/nginx/nginx.conf` and reloads nginx.

To start nginx on login (needs sudo to bind port 443):

```sh
sudo brew services start nginx
```

### 4. mm

```sh
cd /Users/nadeem/Documents/MacMiniServer/mm
bash setup.sh
# Then edit .frontend-env and .backend-env with real values
```

### 5. raddle.teams

```sh
cd /Users/nadeem/Documents/MacMiniServer/raddle.teams
bash setup.sh
# Then edit .env with real values
```

### 6. jeopardy

```sh
cd /Users/nadeem/Documents/MacMiniServer/jeopardy
bash setup.sh
# Then edit .env with real values
```

### 7. cloudflare-dns-update

```sh
cp /Users/nadeem/Documents/MacMiniServer/maida-server/cloudflare-dns-update/.env \
   /Users/nadeem/Documents/MacMiniServer/cloudflare-dns-update/.env
# Or create .env with API_TOKEN=... and ZONE_ID=...

cd /Users/nadeem/Documents/MacMiniServer/cloudflare-dns-update
bash setup.sh
```

To install the cron job manually instead:

```sh
crontab crontab.txt
```

## Local access

`nginx/sites/local.conf` adds `listen 80` HTTP blocks for all services (no SSL) plus a `default_server` catch-all. nginx binds port 80 on all interfaces, so `http://192.168.1.69` is reachable from any LAN device immediately.

For subdomain routing to work from other devices (`http://mm.nadee-mj.dev` → Mac Mini instead of Cloudflare), those devices need to resolve the subdomains to `192.168.1.69`. Options:

- **Router DNS override** _(recommended)_ — add a custom DNS record `*.nadee-mj.dev → 192.168.1.69` in your router admin panel. Covers all devices automatically.
- **Pi-hole** — add a local DNS record under Local DNS → DNS Records.
- **Per-device `/etc/hosts`** — add on each device:

```
192.168.1.69 mm.nadee-mj.dev
192.168.1.69 raddle.nadee-mj.dev
192.168.1.69 jeopardy.nadee-mj.dev
192.168.1.69 jelly.nadee-mj.dev
192.168.1.69 vault.nadee-mj.dev
192.168.1.69 hass.nadee-mj.dev
192.168.1.69 abs.nadee-mj.dev
192.168.1.69 health.nadee-mj.dev
```

On the Mac Mini itself, use `127.0.0.1` instead of `192.168.1.69` in `/etc/hosts`.

Note: port 80 also requires `sudo brew services start nginx`.

## Verification

### Services (launchd)

```sh
launchctl list | grep nadeem
```

All three should appear with a PID (first column) if running:

```
PID   Status  Label
1234  0       com.nadeem.mm
1235  0       com.nadeem.raddle
1236  0       com.nadeem.jeopardy
```

View logs:

```sh
tail -f ~/Library/Logs/mm.log
tail -f ~/Library/Logs/raddle.log
tail -f ~/Library/Logs/jeopardy.log
```

### nginx

```sh
nginx -t                             # test config
curl -sk https://health.nadee-mj.dev # should return 200
```

### cloudflare-dns-update

```sh
crontab -l                           # verify hourly job is present
/opt/homebrew/bin/python3 /Users/nadeem/Documents/MacMiniServer/cloudflare-dns-update/script.py
cat /Users/nadeem/Documents/MacMiniServer/cloudflare-dns-update/logs/cloudflare.log
cat /Users/nadeem/Documents/MacMiniServer/cloudflare-dns-update/cron-logs/cron.log
```

## Managing services

```sh
# Restart a service
launchctl kickstart -k gui/$(id -u)/com.nadeem.mm

# Stop a service
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.nadeem.mm.plist

# Start a service
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.nadeem.mm.plist
```
