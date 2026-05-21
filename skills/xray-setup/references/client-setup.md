# Client Setup

## VLESS URI format (common to all platforms)

```
vless://<UUID>@<HOST>:<PORT>?<params>#<label>
```

### REALITY parameters

```
vless://<UUID>@<SERVER_IP>:443?security=reality&sni=www.microsoft.com&fp=chrome&pbk=<PUBLIC_KEY>&sid=<SHORT_ID>&flow=xtls-rprx-vision&type=tcp#MyServer-REALITY
```

### TLS parameters

```
vless://<UUID>@<YOUR_DOMAIN>:443?security=tls&sni=<YOUR_DOMAIN>&fp=chrome&flow=xtls-rprx-vision&type=tcp#MyServer-TLS
```

Parameter reference:

| Param | Value | Notes |
|-------|-------|-------|
| `security` | `reality` or `tls` | |
| `sni` | domain or server name | Must match `serverNames` for REALITY |
| `fp` | `chrome`, `firefox`, `safari`, `ios`, `android`, `edge`, `random` | TLS fingerprint |
| `pbk` | x25519 public key | REALITY only |
| `sid` | shortId hex string | REALITY only |
| `flow` | `xtls-rprx-vision` | Required for Vision/XTLS |
| `type` | `tcp` | Transport layer |

---

## Android — NekoBox (recommended)

1. Install [NekoBox](https://github.com/MatsuriDayo/NekoBoxForAndroid) from GitHub releases.
2. Tap `+` → Import from clipboard or QR code
3. Paste the VLESS URI
4. Tap the profile to select it
5. Tap the connect button (plane icon)

Alternative: v2rayNG — same steps, supports VLESS URI import.

---

## iOS — Streisand (recommended)

1. Install [Streisand](https://apps.apple.com/app/streisand/id6450534064) from App Store.
2. Tap `+` → Import from QR code or paste link
3. Paste the VLESS URI
4. Tap the config to enable it
5. Toggle VPN on

Alternative: FoXray (App Store).

---

## Windows — v2rayN

1. Download [v2rayN](https://github.com/2dust/v2rayN/releases) — get the `v2rayN-With-Core.zip`.
2. Extract and run `v2rayN.exe`.
3. Servers menu → Add server → VLESS
4. Or: Edit → Import bulk URL from clipboard → paste URI
5. Right-click tray icon → System proxy → Set system proxy

Alternative: Nekoray.

---

## macOS — V2Box or FoXray

**V2Box:**
1. Install from Mac App Store (search "V2Box - V2ray Client").
2. `+` → Import from clipboard
3. Paste URI → connect

**Alternative: sing-box CLI:**

```bash
🖥 LOCAL
brew install sing-box
```

Create `config.json` with the outbound from the VLESS URI, then:

```bash
sing-box run -c config.json
```

---

## Linux — Nekoray

1. Download [Nekoray](https://github.com/MatsuriDayo/nekoray/releases) AppImage or package.
2. Run Nekoray.
3. Profile → New profile → Import from URL
4. Paste VLESS URI → OK
5. Right-click → Start → Enable system proxy

Alternative: v2rayA (web UI):

```bash
🌐 LOCAL (not VPS)
# Install v2rayA
wget -qO - https://apt.v2raya.org/key/public-key.asc | sudo tee /etc/apt/trusted.gpg.d/v2raya.asc
echo "deb https://apt.v2raya.org/ v2raya main" | sudo tee /etc/apt/sources.list.d/v2raya.list
sudo apt-get update && sudo apt-get install -y v2raya
sudo systemctl start v2raya
```

Then open `http://localhost:2017` in your browser, create an account, and
import the VLESS URI.

---

## QR code generation (local)

To make it easier to import on mobile:

```bash
🖥 LOCAL
# Install qrencode if not present
brew install qrencode   # macOS
sudo apt-get install -y qrencode  # Linux

qrencode -t ANSIUTF8 "vless://<UUID>@..."
```

Or paste the URI into an online QR generator — but note that the VLESS URI
contains your UUID, which is an auth credential. Only use an online generator
for a specific user's URI (not the server's private key), and consider that the
UUID may be logged by the third-party service. The local `qrencode` approach
above avoids this entirely.

---

## Testing the connection

After connecting on any client:

1. Visit `https://ipinfo.io` or `https://2ip.ru` — the IP shown should be your VPS IP.
2. Run a speed test.
3. If the IP does not change: the VPN is not routing traffic. Check client proxy settings (system vs per-app proxy mode).

---

## See also

- `xray-vless-reality.md` — REALITY URI construction
- `xray-vless-tls.md` — TLS URI construction
- `troubleshooting.md` — client connection failures
