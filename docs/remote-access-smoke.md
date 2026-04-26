# Remote Access Smoke Runbook

Use this checklist when verifying Kiln from another device over the tailnet.

## 1) Start the remote profile

Set your Tailscale auth key and bring up the remote sidecar:

```bash
TS_AUTHKEY=tskey-auth-... docker compose --profile remote up -d tailscale
```

The compose profile uses the local dashboard on `host.docker.internal:4000` and exposes it through Tailscale MagicDNS.

## 2) Open the tailnet URL from another device

From a phone or laptop already on the same tailnet, open the MagicDNS URL printed by Tailscale, for example:

```text
https://kiln.<your-tailnet>.ts.net
```

## 3) Smoke the auth gate

- Visit the root dashboard URL first.
- Expected: you see the login page before you see the dashboard.
- After logging in, expected: the dashboard loads normally.

## 4) Smoke the public health probe

Open:

```text
https://kiln.<your-tailnet>.ts.net/health
```

Expected: the health probe returns a public 200 response.

## Expected success signals

- Tailscale container starts cleanly with `TS_AUTHKEY` set.
- The MagicDNS URL resolves from the other device.
- Unauthenticated dashboard access lands on `/users/log_in`.
- Authenticated access reaches the dashboard.
- `/health` stays public.

## Failure signals

- The remote container exits with `set TS_AUTHKEY before starting the remote profile`.
- The MagicDNS URL does not resolve from the other device.
- The dashboard opens without a login gate.
- `/health` is redirected or requires auth.

## Stop

When finished:

```bash
docker compose --profile remote down
```
