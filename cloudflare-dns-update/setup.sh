#!/bin/bash
set -e

SCRIPT="/Users/nadeem/Documents/MacMiniServer/cloudflare-dns-update/script.py"
CRON_JOB="0 * * * * /opt/homebrew/bin/python3 $SCRIPT > /Users/nadeem/Documents/MacMiniServer/cloudflare-dns-update/cron-logs/cron.log 2>&1"

# Install cron job if not already present
if crontab -l 2>/dev/null | grep -qF "$SCRIPT"; then
    echo "Cron job already installed."
else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Cron job installed."
fi

crontab -l
