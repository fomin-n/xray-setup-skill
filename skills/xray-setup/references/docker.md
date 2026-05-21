# Docker Installation

## Method: apt repository (recommended for production)

Do not use the convenience script (`curl | bash`) for a server you care about.
The apt method is auditable and updatable via `apt-get upgrade`.

### Ubuntu 22.04 LTS

```bash
🌐 VPS
# Remove any old versions
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine + Compose plugin
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

### Debian 12

Same steps as above but replace `ubuntu` with `debian` in the repository URL:

```bash
curl -fsSL https://download.docker.com/linux/debian/gpg | ...
"deb [...] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
```

---

## Non-root Docker access

If running as a non-root sudo user (recommended), add to the `docker` group:

```bash
🌐 VPS
sudo usermod -aG docker $USER
```

Log out and back in for the group to take effect. Then verify:

```bash
🌐 VPS
docker ps
```

Expected: empty table (not a permission error).

If running as root: Docker works without the group, but avoid running
application containers as root inside the container where possible.

---

## Enable Docker to start on boot

```bash
🌐 VPS
sudo systemctl enable docker
sudo systemctl start docker
```

---

## Docker Compose v2

The skill uses Docker Compose v2 (the plugin, `docker compose`), not the
deprecated v1 (`docker-compose`). Verify:

```bash
🌐 VPS
docker compose version
```

Expected: `Docker Compose version v2.x.x`

---

## Validation

```bash
🌐 VPS — paste output
bash scripts/check_docker.sh
```

Expected output:
- Docker version present
- Docker daemon running
- Compose v2 available
- No unexpected containers running

---

## See also

- `xray-vless-reality.md` — Docker Compose for Xray (REALITY)
- `xray-vless-tls.md` — Docker Compose for Xray (TLS)
- `marzban.md` — Docker Compose for Marzban
