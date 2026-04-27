#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
cd /opt/projects/raddle.teams/
uv run ./rt install --sync
exec uv run ./rt s --host 0.0.0.0

