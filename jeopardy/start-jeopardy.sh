#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
cd /opt/projects/jeopardy/
./j install --sync
exec ./j s --host 0.0.0.0 --port 3000
