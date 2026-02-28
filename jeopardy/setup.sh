#!/bin/bash
set -e

# Ensure /opt/projects exists
if [ ! -d /opt/projects ]; then
    echo "Please run: sudo mkdir /opt/projects && sudo chown nadeem /opt/projects"
    exit 1
fi

cd /opt/projects
gh repo clone Simonlemayy/jeopardy
cd jeopardy

cp .env.example .env
ln -s /opt/projects/jeopardy/.env /Users/nadeem/Documents/MacMiniServer/jeopardy/.env

uv sync

# Setup the launchd agent
PLIST_SRC="/Users/nadeem/Documents/MacMiniServer/jeopardy/com.nadeem.jeopardy.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.nadeem.jeopardy.plist"

if [ -L "$PLIST_DEST" ]; then
    launchctl bootout gui/$(id -u) "$PLIST_DEST" 2>/dev/null || true
    rm "$PLIST_DEST"
fi

ln -s "$PLIST_SRC" "$PLIST_DEST"
launchctl bootstrap gui/$(id -u) "$PLIST_DEST"
launchctl list | grep com.nadeem.jeopardy || true
