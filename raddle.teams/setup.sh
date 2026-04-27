#!/bin/bash
set -e

# Ensure /opt/projects exists
if [ ! -d /opt/projects ]; then
    echo "Please run: sudo mkdir /opt/projects && sudo chown nadeem /opt/projects"
    exit 1
fi

cd /opt/projects
if [ -d /opt/projects/raddle.teams ]; then
    echo "/opt/projects/raddle.teams already exists; skipping clone"
else
    gh repo clone NADEE-MJ/raddle.teams
fi

cd raddle.teams

if [ -e .env ]; then
    echo ".env already exists; skipping"
else
    cp .env.example .env
fi

if [ -e /Users/nadeem/Documents/MacMiniServer/raddle.teams/.env ] || [ -L /Users/nadeem/Documents/MacMiniServer/raddle.teams/.env ]; then
    echo ".env symlink already exists; skipping"
else
    ln -s /opt/projects/raddle.teams/.env /Users/nadeem/Documents/MacMiniServer/raddle.teams/.env
fi

uv sync

# Setup the launchd agent
PLIST_SRC="/Users/nadeem/Documents/MacMiniServer/raddle.teams/com.nadeem.raddle.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.nadeem.raddle.plist"

echo "Recreating LaunchAgent plist at $PLIST_DEST"
launchctl bootout gui/$(id -u) "$PLIST_DEST" 2>/dev/null || true
rm -f "$PLIST_DEST"
cp "$PLIST_SRC" "$PLIST_DEST"
launchctl bootstrap gui/$(id -u) "$PLIST_DEST"

launchctl list | grep com.nadeem.raddle || true
