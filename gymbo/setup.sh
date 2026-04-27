#!/bin/bash
set -e

# Ensure /opt/projects exists
if [ ! -d /opt/projects ]; then
    echo "Please run: sudo mkdir /opt/projects && sudo chown nadeem /opt/projects"
    exit 1
fi

cd /opt/projects
if [ -d /opt/projects/gymbo ]; then
    echo "/opt/projects/gymbo already exists; skipping clone"
else
    gh repo clone NADEE-MJ/gymbo
fi

cd gymbo

if [ -e backend/.env ]; then
    echo "backend/.env already exists; skipping"
else
    cp backend/.env.example backend/.env
fi

if [ -e frontend/.env ]; then
    echo "frontend/.env already exists; skipping"
else
    cp frontend/.env.example frontend/.env
fi

if [ -e /Users/nadeem/Documents/MacMiniServer/gymbo/.frontend-env ] || [ -L /Users/nadeem/Documents/MacMiniServer/gymbo/.frontend-env ]; then
    echo ".frontend-env already exists; skipping"
else
    ln -s /opt/projects/gymbo/frontend/.env /Users/nadeem/Documents/MacMiniServer/gymbo/.frontend-env
fi

if [ -e /Users/nadeem/Documents/MacMiniServer/gymbo/.backend-env ] || [ -L /Users/nadeem/Documents/MacMiniServer/gymbo/.backend-env ]; then
    echo ".backend-env already exists; skipping"
else
    ln -s /opt/projects/gymbo/backend/.env /Users/nadeem/Documents/MacMiniServer/gymbo/.backend-env
fi

npm run install:all

# Setup the launchd agent
PLIST_SRC="/Users/nadeem/Documents/MacMiniServer/gymbo/com.nadeem.gymbo.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.nadeem.gymbo.plist"

echo "Recreating LaunchAgent plist at $PLIST_DEST"
launchctl bootout gui/$(id -u) "$PLIST_DEST" 2>/dev/null || true
rm -f "$PLIST_DEST"
cp "$PLIST_SRC" "$PLIST_DEST"
launchctl bootstrap gui/$(id -u) "$PLIST_DEST"

launchctl list | grep com.nadeem.gymbo || true
