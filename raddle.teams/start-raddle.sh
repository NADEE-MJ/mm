#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
cd /opt/projects/raddle.teams/
./rt install --sync
exec ./rt s --host 0.0.0.0
