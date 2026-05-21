# Decision Tree

Use this to select the installation path based on the user's answers from
Phase 1 of the skill workflow.

## Step 1 — Is the VPS fresh?

**Fresh** means: no web server, no Docker services, no Xray, no Marzban
currently running. A newly provisioned VPS is always fresh.

Run `scripts/collect_server_info.sh` to confirm for "existing" claims.

```
Q: Is this a fresh VPS with no conflicting services on ports 80/443?
├─ YES → Go to Step 2
└─ NO  → Path D (Existing server migration)
```

## Step 2 — Is a domain available?

```
Q: Does the user have a domain name?
├─ NO  → Path A (REALITY, no domain)
└─ YES → Go to Step 3
```

## Step 3 — Is the domain DNS pointed at the server?

```
Q: Does `check_dns.sh <domain> <server-ip>` confirm the A record matches?
├─ NO  → Pause. DNS is not ready. Instruct user to create A record,
│         then wait for propagation (typically 5–30 minutes, up to 48h).
│         Re-run check_dns.sh before proceeding.
└─ YES → Go to Step 4
```

## Step 4 — Is Cloudflare used?

```
Q: Is the domain on Cloudflare?
├─ NO (or other DNS provider) → Path B (TLS, direct)
└─ YES → Go to Step 5
```

## Step 5 — Is Cloudflare proxying the traffic?

```
Q: Is the DNS record orange-cloud (proxied) or grey-cloud (DNS-only)?
├─ Grey-cloud (DNS-only) → Path B (TLS, direct — CF just does DNS)
└─ Orange-cloud (proxied) → Path C (Cloudflare-proxied special handling)
```

## Step 6 — Marzban?

Applies to all paths. Ask separately.

```
Q: Does the user want Marzban?
├─ NO  → Skip Phase 9 in the skill workflow
└─ YES → Phase 9 applies; then ask dashboard access preference:
          (a) SSH tunnel only     → references/dashboard-security.md#ssh-tunnel
          (b) Private HTTPS path  → references/dashboard-security.md#reverse-proxy
          (c) Public HTTPS        → warn explicitly; document risks before proceeding
```

---

## Path Summary

### Path A — VLESS + REALITY (no domain)

**When:** Fresh VPS, no domain.

**How it works:** Xray listens directly on port 443. REALITY makes the
connection look like a TLS handshake to a real website (configurable
`serverNames`). No domain, no certificate, no web server needed.

**Pros:** Simplest setup; no DNS dependency; hardest to fingerprint.

**Cons:** No HTTPS fallback site; slightly less flexible for Marzban TLS setup.

**References:** `xray-vless-reality.md`

---

### Path B — VLESS + TLS (domain, no CF proxy)

**When:** Fresh VPS, domain A record points directly to server IP.

**How it works:** Angie handles port 443, terminates TLS with a Let's Encrypt
cert, and forwards the VLESS traffic via `proxy_protocol` to Xray. Angie also
serves a normal-looking HTTPS fallback site on the same port.

**Pros:** Real domain; proper TLS cert; HTTPS fallback looks legitimate;
Marzban can use the same domain for its own TLS.

**Cons:** Requires domain; DNS must propagate before certbot can issue cert;
Cloudflare must be DNS-only.

**References:** `xray-vless-tls.md`, `angie-proxy.md`

---

### Path C — VLESS + TLS with Cloudflare proxied

**When:** Domain is behind Cloudflare orange-cloud proxy.

**Important constraints:**
- Cloudflare terminates TLS between client and CF edge.
- Traffic between CF edge and your VPS can use CF Origin Certificate or
  a self-signed cert — NOT Let's Encrypt (CF doesn't forward ACME challenges
  in proxied mode by default).
- Xray REALITY does not work behind CF proxy (CF proxies don't forward raw TLS).
- You must use VLESS+TLS where CF acts as the outer TLS layer.

**Decision:** Either switch the domain record to DNS-only (grey-cloud) and
follow Path B, or configure CF Origin Certificate and CF-specific Angie setup.

**References:** `cloudflare.md`, `angie-proxy.md`

---

### Path D — Existing server migration

**When:** Server has existing services (nginx, other Docker containers, etc.).

**Approach:**
1. Run `collect_server_info.sh` and analyze conflicts.
2. If port 443 is taken by nginx: consider adding Xray as a location block
   in nginx, or migrate nginx to a different port and put Angie on 443, or
   use REALITY on a non-443 port with port forwarding.
3. Never overwrite existing configs without explicit backup confirmation.
4. Prefer additive changes over replacements.

**References:** All references as needed based on what is found.

---

### Path E — Marzban only (Xray already running)

**When:** Xray is already installed and working; user wants to add Marzban.

**Approach:**
1. Verify Xray config is compatible with Marzban's inbound format.
2. Install Marzban, point it at the existing Xray socket or API endpoint.
3. Do not restart Xray unless necessary.

**References:** `marzban.md`, `dashboard-security.md`

---

## Re-check triggers

Re-run the relevant check scripts and revisit the tree if:
- User reports DNS changed
- User switched Cloudflare from proxied to DNS-only
- User provisioned a new VPS after an earlier failed attempt
- Port 443 conflict appeared after running `check_ports.sh`
