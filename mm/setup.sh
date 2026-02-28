#!/bin/bash
set -e

# Ensure /opt/projects exists
if [ ! -d /opt/projects ]; then
    echo "Please run: sudo mkdir /opt/projects && sudo chown nadeem /opt/projects"
    exit 1
fi

cd /opt/projects
gh repo clone NADEE-MJ/mm
cd mm

cp frontend/.env.example frontend/.env
cp backend/.env.example backend/.env
ln -s /opt/projects/mm/frontend/.env /Users/nadeem/Documents/MacMiniServer/mm/.frontend-env
ln -s /opt/projects/mm/backend/.env /Users/nadeem/Documents/MacMiniServer/mm/.backend-env

npm run install:all

# Setup the launchd agent
PLIST_SRC="/Users/nadeem/Documents/MacMiniServer/mm/com.nadeem.mm.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.nadeem.mm.plist"

if [ -L "$PLIST_DEST" ]; then
    launchctl bootout gui/$(id -u) "$PLIST_DEST" 2>/dev/null || true
    rm "$PLIST_DEST"
fi

ln -s "$PLIST_SRC" "$PLIST_DEST"
launchctl bootstrap gui/$(id -u) "$PLIST_DEST"
launchctl list | grep com.nadeem.mm || true
