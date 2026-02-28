#!/bin/bash
set -e

# Ensure /opt/projects exists
if [ ! -d /opt/projects ]; then
    echo "Please run: sudo mkdir /opt/projects && sudo chown nadeem /opt/projects"
    exit 1
fi

cd /opt/projects
gh repo clone NADEE-MJ/gymbo
cd gymbo

cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
ln -s /opt/projects/gymbo/frontend/.env /Users/nadeem/Documents/MacMiniServer/gymbo/.frontend-env
ln -s /opt/projects/gymbo/backend/.env /Users/nadeem/Documents/MacMiniServer/gymbo/.backend-env

npm run install:all

# Setup the launchd agent
PLIST_SRC="/Users/nadeem/Documents/MacMiniServer/gymbo/com.nadeem.gymbo.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.nadeem.gymbo.plist"

if [ -L "$PLIST_DEST" ]; then
    launchctl bootout gui/$(id -u) "$PLIST_DEST" 2>/dev/null || true
    rm "$PLIST_DEST"
fi

ln -s "$PLIST_SRC" "$PLIST_DEST"
launchctl bootstrap gui/$(id -u) "$PLIST_DEST"
launchctl list | grep com.nadeem.gymbo || true
