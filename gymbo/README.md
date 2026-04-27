# Gymbo

Full-stack gym tracker with:
- Web client (React + Vite)
- Native iOS client (SwiftUI + GRDB)
- FastAPI backend (SQLite + Alembic)

## Repository Layout

```text
gymbo/
├── backend/                 # FastAPI API + data model + migrations
├── frontend/                # React web app
├── mobile/                  # Native Swift iOS app
├── scripts/gymbo-cli.sh     # Repo CLI wrapper used by npm scripts
└── package.json             # Root scripts
```

## Quick Start (Web + Backend)

1. Install dependencies

```bash
npm run install:all
```

2. Configure environment

```bash
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
```

3. Run database migrations

```bash
npm run backend:migrate
```

4. Start backend

```bash
npm run backend:start
```

Backend URL: `http://localhost:8002`

5. Start frontend (new terminal)

```bash
npm run frontend:dev
```

Frontend URL: `http://localhost:5173`

### Admin Account Provisioning

Open `http://localhost:5173/admin` and:
- sign in with `ADMIN_TOKEN` from `backend/.env`
- create user accounts for app/web login

## iOS App

```bash
cd mobile
cp .env.example .env
cd ..
npm run mobile:env
npm run swift:xcodegen
```

Then open `mobile/Gymbo.xcodeproj` in Xcode.

### Manual iOS Release (Mac mini)

```bash
npm run mobile:release
```

This command will:
- generate env config
- regenerate the Xcode project
- build an unsigned Release IPA
- create/update GitHub release tag `mobile-v{MARKETING_VERSION}`
- upload the IPA to that release

Useful options:

```bash
npm run mobile:release -- --no-publish
npm run mobile:release -- --suffix rc1
npm run mobile:release -- --api-base-url https://api.yourdomain.com/api
npm run mobile:release -- --file-logging NO
```

## Useful Commands

```bash
npm run help
npm run install:all
npm run install:sync
npm run backend:migrate
npm run backend:migrate:status
npm run backend:migrate:down -- -1
npm run backend:start
npm run frontend:dev
npm run mobile:env
npm run mobile:release
npm run swift:xcodegen
npm run swift:build
npm run swift:run
npm run simulator:list
npm run simulator:boot
```

## Direct CLI Usage

You can also run the wrapper directly:

```bash
bash scripts/gymbo-cli.sh help
```
