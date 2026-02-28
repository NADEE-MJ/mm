# ServerPilot

Tailscale-first server control app (`mobile/`) and backend daemon (`backend/`).

## Networking Model

- Backend API is intended to be reachable only over your Tailscale tailnet.
- Transport security is provided by the WireGuard tunnel and Tailscale identity.
- API requests are still signed per request with Secure Enclave keys (`X-Signature`, nonce, timestamp).

## What Was Removed (vs internet/public-host model)

- No Cloudflare/public-domain dependency for ServerPilot API.
- No certificate pinning logic in iOS app.
- No pre-auth IP rate limiter in backend middleware.

## Required Setup

1. Install Bun and dependencies:
   - `cd backend && bun install`
2. Configure `.env` from `.env.example`.
3. Set `API_HOST` to your server's Tailscale IP (example: `100.64.x.x`).
4. Ensure firewall/policy only permits tailnet clients.
5. Run backend:
   - `bun run src/index.ts`
6. In iOS config (`mobile/Config/App.xcconfig`), set:
   - `API_BASE_URL = http://<tailscale-ip>:4310`

## Security Notes

- Keep `ADMIN_TOKEN` long/random.
- Keep `POSTAUTH_RATE_LIMIT_PER_MINUTE` enabled.
- Keep device signature verification + nonce replay protections enabled.
