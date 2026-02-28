#!/bin/bash
set -e

REPO_DIR="/Users/nadeem/Documents/MacMiniServer/nginx"
NGINX_ETC="/opt/homebrew/etc/nginx"

# ── nginx.conf ────────────────────────────────────────────────────────────────
# Copy (not symlink) so the root LaunchDaemon can read it without TCC blocking
NGINX_CONF_DEST="$NGINX_ETC/nginx.conf"
if [ -L "$NGINX_CONF_DEST" ]; then
    sudo rm "$NGINX_CONF_DEST"
elif [ -f "$NGINX_CONF_DEST" ]; then
    sudo cp "$NGINX_CONF_DEST" "${NGINX_CONF_DEST}.bak"
    sudo rm "$NGINX_CONF_DEST"
fi
sudo cp "$REPO_DIR/nginx.conf" "$NGINX_CONF_DEST"
sudo chown root:wheel "$NGINX_CONF_DEST"
sudo chmod 644 "$NGINX_CONF_DEST"
echo "Copied nginx.conf -> $NGINX_CONF_DEST"

# ── SSL keys ──────────────────────────────────────────────────────────────────
KEYS_DEST="$NGINX_ETC/keys"
sudo mkdir -p "$KEYS_DEST"
sudo cp "$REPO_DIR/keys/cloudflare.pem" "$KEYS_DEST/cloudflare.pem"
sudo cp "$REPO_DIR/keys/cloudflare.key" "$KEYS_DEST/cloudflare.key"
sudo chown root:wheel "$KEYS_DEST/cloudflare.pem" "$KEYS_DEST/cloudflare.key"
sudo chmod 644 "$KEYS_DEST/cloudflare.pem"
sudo chmod 600 "$KEYS_DEST/cloudflare.key"
echo "Copied SSL keys -> $KEYS_DEST"

# ── site configs ──────────────────────────────────────────────────────────────
SITES_DEST="$NGINX_ETC/sites"
sudo mkdir -p "$SITES_DEST"
for conf in "$REPO_DIR/sites/"*.conf; do
    fname="$(basename "$conf")"
    sudo cp "$conf" "$SITES_DEST/$fname"
    sudo chown root:wheel "$SITES_DEST/$fname"
    sudo chmod 644 "$SITES_DEST/$fname"
    echo "Copied site config: $fname -> $SITES_DEST/$fname"
done

# ── log file ownership ────────────────────────────────────────────────────────
# LaunchDaemon runs as root; ensure root owns the log files
sudo chown root:wheel /opt/homebrew/var/log/nginx/access.log \
                      /opt/homebrew/var/log/nginx/error.log 2>/dev/null || true
sudo chmod 644 /opt/homebrew/var/log/nginx/access.log \
               /opt/homebrew/var/log/nginx/error.log 2>/dev/null || true

# ── test config ───────────────────────────────────────────────────────────────
sudo nginx -t

# ── LaunchDaemon ──────────────────────────────────────────────────────────────
PLIST_SRC="$REPO_DIR/com.nadeem.nginx.plist"
PLIST_DEST="/Library/LaunchDaemons/com.nadeem.nginx.plist"

if [ -L "$PLIST_DEST" ] || [ -f "$PLIST_DEST" ]; then
    sudo launchctl bootout system "$PLIST_DEST" 2>/dev/null || true
    sudo rm "$PLIST_DEST"
fi

sudo cp "$PLIST_SRC" "$PLIST_DEST"
sudo chown root:wheel "$PLIST_DEST"
sudo chmod 644 "$PLIST_DEST"
sudo launchctl bootstrap system "$PLIST_DEST"
echo "nginx LaunchDaemon loaded"
