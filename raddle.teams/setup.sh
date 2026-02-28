#!/bin/bash
set -e

# Ensure /opt/projects exists
if [ ! -d /opt/projects ]; then
    echo "Please run: sudo mkdir /opt/projects && sudo chown nadeem /opt/projects"
    exit 1
fi

cd /opt/projects
gh repo clone NADEE-MJ/raddle.teams
cd raddle.teams

bash setup.sh
cp .env.example .env
ln -s /opt/projects/raddle.teams/.env /Users/nadeem/Documents/MacMiniServer/raddle.teams/.env

uv sync

# Setup the launchd agent
PLIST_SRC="/Users/nadeem/Documents/MacMiniServer/raddle.teams/com.nadeem.raddle.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.nadeem.raddle.plist"

if [ -L "$PLIST_DEST" ]; then
    launchctl bootout gui/$(id -u) "$PLIST_DEST" 2>/dev/null || true
    rm "$PLIST_DEST"
fi

ln -s "$PLIST_SRC" "$PLIST_DEST"
launchctl bootstrap gui/$(id -u) "$PLIST_DEST"
launchctl list | grep com.nadeem.raddle || true
