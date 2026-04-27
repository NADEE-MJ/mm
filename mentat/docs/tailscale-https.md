# Tailscale HTTPS Setup for Mentat

Mentat requires HTTPS. The app rejects plain HTTP connections at startup. This guide walks through enabling Tailscale's built-in HTTPS certificate provisioning so your backend gets a valid TLS cert on a `*.ts.net` domain with zero infrastructure.

---

## How it works

Tailscale operates a built-in certificate authority (using Let's Encrypt under the hood). When you enable HTTPS for your tailnet, each machine gets a DNS name of the form:

```
<machine-name>.<tailnet-name>.ts.net
```

Tailscale issues a real, browser-trusted TLS certificate for that name. No self-signed certs, no custom CA, no reverse proxy required — just `tailscale cert` and a flag in your server config.

---

## Step 1 — Enable HTTPS in the Tailscale admin console

1. Open [https://login.tailscale.com/admin/dns](https://login.tailscale.com/admin/dns).
2. Scroll to the **HTTPS Certificates** section.
3. Click **Enable HTTPS**.

This enables certificate provisioning for every machine in your tailnet.

---

## Step 2 — Find your machine's Tailscale hostname

On the machine running the Mentat backend, run:

```bash
tailscale status
```

Your machine will have a name like `my-mac` and a tailnet name visible in the admin console (e.g. `tail1234.ts.net`). The full hostname is:

```
my-mac.tail1234.ts.net
```

You can also confirm it with:

```bash
tailscale cert --help
# or check the Machines tab at https://login.tailscale.com/admin/machines
```

---

## Step 3 — Provision the TLS certificate

On the machine that will run the Mentat backend:

```bash
tailscale cert my-mac.tail1234.ts.net
```

This creates two files in the current directory (or wherever you run the command):

| File | Contents |
|------|----------|
| `my-mac.tail1234.ts.net.crt` | Full certificate chain (PEM) |
| `my-mac.tail1234.ts.net.key` | Private key (PEM) |

Move them somewhere persistent, e.g.:

```bash
sudo mkdir -p /etc/mentat/tls
sudo mv my-mac.tail1234.ts.net.crt /etc/mentat/tls/cert.pem
sudo mv my-mac.tail1234.ts.net.key /etc/mentat/tls/key.pem
sudo chmod 600 /etc/mentat/tls/key.pem
```

Certificates are valid for 90 days. Run `tailscale cert` again to renew — the file paths stay the same.

---

## Step 4 — Configure the Mentat backend

The backend's `Bun.serve()` accepts `tls` options. In `backend/.env`, set the certificate paths and bind to the Tailscale IP (not `0.0.0.0` — binding to the Tailscale interface restricts access to tailnet members only):

```bash
# backend/.env

# Bind to your machine's Tailscale IP (100.x.y.z)
# Find it with: tailscale ip -4
API_HOST=100.64.x.x
API_PORT=4310
ADMIN_PORT=4311

TLS_CERT_PATH=/etc/mentat/tls/cert.pem
TLS_KEY_PATH=/etc/mentat/tls/key.pem
```

Then update `backend/src/index.ts` to pass the cert/key to `Bun.serve()`:

```ts
Bun.serve({
  port: appConfig.API_PORT,
  hostname: appConfig.API_HOST,
  fetch: app.fetch,
  tls: appConfig.TLS_CERT_PATH && appConfig.TLS_KEY_PATH
    ? {
        cert: Bun.file(appConfig.TLS_CERT_PATH),
        key: Bun.file(appConfig.TLS_KEY_PATH),
      }
    : undefined,
});
```

> The admin server (`ADMIN_PORT`) listens on `127.0.0.1` only and should **not** have TLS — it is localhost-only and never reachable from the network.

---

## Step 5 — Configure the iOS app

In `mobile/.env`, set your Tailscale HTTPS URL as the API base URL:

```bash
API_BASE_URL=https://my-mac.tail1234.ts.net:4310
```

Then regenerate the xcconfig:

```bash
npm run swift:xcconfig
```

The app enforces `https://` at launch — if you accidentally set an `http://` URL, the app will crash immediately with a clear error message.

---

## Certificate renewal

Tailscale certificates expire after 90 days. Renew with the same command:

```bash
tailscale cert my-mac.tail1234.ts.net
```

If you placed the cert at the same paths, the backend will pick up the new cert on its next restart. To avoid downtime, set up a cron job or launchd plist to renew and restart automatically:

```bash
# Example: renew weekly on Sunday at 3am
0 3 * * 0 tailscale cert my-mac.tail1234.ts.net && \
  cp my-mac.tail1234.ts.net.crt /etc/mentat/tls/cert.pem && \
  cp my-mac.tail1234.ts.net.key /etc/mentat/tls/key.pem && \
  launchctl kickstart -k gui/$(id -u)/com.nadeem.mentat 2>/dev/null || true
```

---

## Troubleshooting

**`tailscale cert` returns "HTTPS is not enabled for your tailnet"**
Go to the admin console → DNS → enable HTTPS Certificates.

**Certificate issued for wrong hostname**
Use `tailscale status` to confirm the exact machine name. The name must match exactly what you pass to `tailscale cert` and what you put in `API_BASE_URL`.

**App crashes at launch with "API_BASE_URL must use https://"**
Your `mobile/.env` still has an `http://` URL. Update it and re-run `npm run swift:xcconfig`.

**`curl https://my-mac.tail1234.ts.net:4310/health` fails with "connection refused"**
The backend is either not running, bound to the wrong interface, or `API_HOST` is set to `127.0.0.1` instead of your Tailscale IP. Check `tailscale ip -4` and update `API_HOST`.

**`curl` fails with "certificate verify failed"**
The cert was provisioned for a different hostname than the one in the URL. Make sure the hostname in `API_BASE_URL` exactly matches the argument you passed to `tailscale cert`.
