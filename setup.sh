#!/bin/bash
set -e

# Ensure /opt/projects exists
if [ ! -d /opt/projects ]; then
    echo "Please run: sudo mkdir /opt/projects && sudo chown nadeem /opt/projects"
    exit 1
fi

cd /opt/projects
if [ -d /opt/projects/mm ]; then
    echo "/opt/projects/mm already exists; skipping clone"
else
    gh repo clone NADEE-MJ/mm
fi

cd mm

if [ -e frontend/.env ]; then
    echo "frontend/.env already exists; skipping"
else
    cp frontend/.env.example frontend/.env
fi

if [ -e backend/.env ]; then
    echo "backend/.env already exists; skipping"
else
    cp backend/.env.example backend/.env
fi

npm run install:all

# Setup the launchd agent
PLIST_SRC="/Users/nadeem/Documents/MacMiniServer/mm/com.nadeem.mm.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.nadeem.mm.plist"

echo "Recreating LaunchAgent plist at $PLIST_DEST"
launchctl bootout gui/$(id -u) "$PLIST_DEST" 2>/dev/null || true
rm -f "$PLIST_DEST"
cp "$PLIST_SRC" "$PLIST_DEST"
launchctl bootstrap gui/$(id -u) "$PLIST_DEST"

launchctl list | grep com.nadeem.mm || true
