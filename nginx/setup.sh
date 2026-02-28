#!/bin/bash
set -e

NGINX_CONF_SRC="/Users/nadeem/Documents/MacMiniServer/nginx/nginx.conf"
NGINX_CONF_DEST="/opt/homebrew/etc/nginx/nginx.conf"

# Back up original if not already a symlink
if [ -f "$NGINX_CONF_DEST" ] && [ ! -L "$NGINX_CONF_DEST" ]; then
    mv "$NGINX_CONF_DEST" "${NGINX_CONF_DEST}.bak"
fi

# Remove existing symlink if present
if [ -L "$NGINX_CONF_DEST" ]; then
    rm "$NGINX_CONF_DEST"
fi

ln -s "$NGINX_CONF_SRC" "$NGINX_CONF_DEST"
echo "Linked $NGINX_CONF_SRC -> $NGINX_CONF_DEST"

# Test config
sudo nginx -t

# Install LaunchDaemon
PLIST_SRC="/Users/nadeem/Documents/MacMiniServer/nginx/com.nadeem.nginx.plist"
PLIST_DEST="/Library/LaunchDaemons/com.nadeem.nginx.plist"

if [ -L "$PLIST_DEST" ] || [ -f "$PLIST_DEST" ]; then
    sudo launchctl bootout system "$PLIST_DEST" 2>/dev/null || true
    sudo rm "$PLIST_DEST"
fi

sudo cp "$PLIST_SRC" "$PLIST_DEST"
sudo launchctl bootstrap system "$PLIST_DEST"
echo "nginx LaunchDaemon loaded"
