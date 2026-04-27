#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
cd /opt/projects/mm/
npm run install:sync
npm run backend:migrate
exec npm run start -- --host 0.0.0.0 --port 8155
