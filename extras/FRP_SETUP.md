# FRP Server Setup on Debian/Ubuntu

Complete guide to setting up FRP server (frps) on Debian or Ubuntu VPS.

## Prerequisites

- Debian 10+, Ubuntu 20.04+, or similar
- Root or sudo access
- Open ports: 7000 (frp control), 7777 (Terraria), 7500 (dashboard)

## Quick Install (Debian/Ubuntu)

```bash
# 1. Download FRP
cd /tmp
ARCH=$(uname -m)
case $ARCH in
    x86_64)  FRP_ARCH="amd64" ;;
    aarch64) FRP_ARCH="arm64" ;;
    *)       echo "Unsupported: $ARCH" && exit 1 ;;
esac

# Get latest version
FRP_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
echo "Installing FRP $FRP_VERSION..."

# Download
wget "https://github.com/fatedier/frp/releases/download/${FRP_VERSION}/frp_${FRP_VERSION#v}_linux_${FRP_ARCH}.tar.gz"

# Extract and install
tar -xzf frp_${FRP_VERSION#v}_linux_${FRP_ARCH}.tar.gz
sudo mv frp_${FRP_VERSION#v}_linux_${FRP_ARCH}/frps /usr/local/bin/
sudo chmod +x /usr/local/bin/frps
rm -rf frp_*

# 2. Create config directory
sudo mkdir -p /etc/frp

# 3. Generate secure token
FRP_TOKEN="your_secure_token"

# 4. Create server config
sudo tee /etc/frp/frps.toml > /dev/null << 'EOF'
# FRP Server Configuration
bindPort = 7000

# Dashboard (web UI) - Optional but recommended
webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "admin"
webServer.password = "password"

# Authentication - MUST match docker-compose.yml
auth.token = "your_secure_token"

# Optional: Limit which ports clients can expose
allowPorts = [
  { start = 7000, end = 8000 }
]
EOF

# 5. Configure firewall (if using UFW)
sudo ufw allow 7000/tcp comment 'FRP Server'
sudo ufw allow 7777/tcp comment 'Terraria'
sudo ufw allow 7500/tcp comment 'FRP Dashboard'

# Or if using iptables directly
sudo iptables -A INPUT -p tcp --dport 7000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 7777 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 7500 -j ACCEPT

# Save iptables rules
sudo netfilter-persistent save  # Debian
# or
sudo iptables-save | sudo tee /etc/iptables/rules.v4  # Ubuntu

# 6. Create systemd service
sudo tee /etc/systemd/system/frps.service > /dev/null << 'EOF'
[Unit]
Description=FRP Server Daemon
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
Restart=always
RestartSec=5s
LimitNOFILE=65536

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=frps

# Security
User=nobody
Group=nogroup
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# 7. Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable frps
sudo systemctl start frps

# 8. Verify installation
sudo systemctl status frps
sudo journalctl -u frps -f
```

## Verification

```bash
# Check if frps is running
sudo systemctl status frps

# Check listening ports
sudo ss -tulpn | grep frps
# Should show:
# 0.0.0.0:7000  (frp control)
# 0.0.0.0:7500  (dashboard)
# 0.0.0.0:7777  (when client connects)

# View logs
sudo journalctl -u frps -f

# Test dashboard (from your local machine)
curl http://your-vps-ip:7500
# Login: admin / password
```

## Your Configuration

**Server (VPS):** `your-vps-ip`
- Control Port: `7000`
- Dashboard: `7500` (admin/password)
- Game Port: `7777`
- Token: `your_secure_token`

**Client (Docker):** Already configured in `docker-compose.yml`

## Troubleshooting

### Service won't start

```bash
# Check logs
sudo journalctl -u frps -n 50

# Test config
sudo -u nobody /usr/local/bin/frps verify -c /etc/frp/frps.toml

# Check if port is already in use
sudo ss -tulpn | grep -E '7000|7500'
```

### Connection refused from client

```bash
# Check firewall
sudo ufw status
# or
sudo iptables -L -n | grep -E '7000|7777|7500'

# Ensure service is running
sudo systemctl status frps

# Test from VPS itself
curl http://localhost:7500

# Check if token matches
grep "auth.token" /etc/frp/frps.toml
# Should show: your_secure_token
```

### Can't see dashboard

```bash
# Ensure webServer is enabled
grep -A3 "webServer" /etc/frp/frps.toml

# Check if port 7500 is listening
sudo ss -tulpn | grep 7500

# Test locally
curl http://localhost:7500
```

### Port binding error

```bash
# Check what's using the port
sudo lsof -i :7000
sudo lsof -i :7500

# Kill conflicting process if needed
sudo lsof -ti :7000 | xargs sudo kill -9
```

## Client-Side Testing

```bash
# On your local machine with docker-compose
cd terraria-docker

# Start services
docker-compose up -d

# Check FRP logs
docker-compose logs -f frp

# Should see:
# "start proxy success"
# "connect to server your-vps-ip:7000 success"

# From another machine, test Terraria connection
telnet your-vps-ip 7777
```

## Configuration Options

### Enable TLS (Recommended for production)

```bash
# Install certbot
sudo apt update
sudo apt install -y certbot

# Get certificate for your domain
sudo certbot certonly --standalone -d your-domain.com

# Update config
sudo tee /etc/frp/frps.toml > /dev/null << 'EOF'
bindPort = 7000

# Enable TLS
transport.tls.force = true
transport.tls.certFile = "/etc/letsencrypt/live/your-domain.com/fullchain.pem"
transport.tls.keyFile = "/etc/letsencrypt/live/your-domain.com/privkey.pem"

webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "admin"
webServer.password = "password"

auth.token = "your_secure_token"
EOF

sudo systemctl restart frps
```

### Performance Tuning

```toml
# /etc/frp/frps.toml

# Connection pooling (for better performance)
transport.maxPoolCount = 5

# TCP multiplexing (default: true)
transport.tcpMux = true

# Heartbeat timeout
transport.heartbeatTimeout = 90

# Log level
log.level = "info"
log.maxDays = 7
```

### Multiple Services

The current config supports multiple clients connecting with different `remotePort` values. Each client in `docker-compose.yml` can use a different remote port:

```yaml
# Service 1 (Terraria)
- FRP_REMOTE_PORT=7777

# Service 2 (Another game)
- FRP_REMOTE_PORT=7778

# Service 3 (Web server)
- FRP_PROXY_TYPE=http
- FRP_REMOTE_PORT=80
```

## Security Best Practices

1. **Change dashboard password**:
   ```bash
   sudo sed -i 's/password/YOUR_STRONG_PASSWORD/g' /etc/frp/frps.toml
   sudo systemctl restart frps
   ```

2. **Use strong tokens** (already set)

3. **Firewall rules** - Only expose necessary ports

4. **Disable dashboard if not needed**:
   ```toml
   # Comment out webServer section in /etc/frp/frps.toml
   ```

5. **Regular updates**:
   ```bash
   # Check for updates
   FRP_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
   echo "Latest: $FRP_VERSION"
   /usr/local/bin/frps --version
   ```

## Management Commands

```bash
# Start/Stop/Restart
sudo systemctl start frps
sudo systemctl stop frps
sudo systemctl restart frps

# Enable/disable on boot
sudo systemctl enable frps
sudo systemctl disable frps

# View logs
sudo journalctl -u frps -f          # Follow logs
sudo journalctl -u frps -n 100      # Last 100 lines
sudo journalctl -u frps --since today  # Today's logs

# Check status
sudo systemctl status frps

# Reload config (if frps supports it)
sudo systemctl reload frps

# Test configuration
/usr/local/bin/frps verify -c /etc/frp/frps.toml
```

## Docker Client Config Reference

Your `docker-compose.yml` is configured with:

```yaml
frp:
  environment:
    - FRP_SERVER_ADDR=your-vps-ip
    - FRP_SERVER_PORT=7000
    - FRP_TOKEN=your_secure_token
    - FRP_LOCAL_PORT=7777
    - FRP_LOCAL_HOST=terraria
    - FRP_REMOTE_PORT=7777
    - FRP_PROXY_NAME=terraria
    - FRP_PROXY_TYPE=tcp
```

This matches the server config above.

## Links

- [FRP GitHub](https://github.com/fatedier/frp)
- [FRP Documentation](https://github.com/fatedier/frp#table-of-contents)
- [Systemd Service Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)

## Summary

After setup:
1. Server runs on VPS `your-vps-ip:7000`
2. Dashboard at `http://your-vps-ip:7500` (admin/changeme)
3. Terraria exposed on `your-vps-ip:7777`
4. Single tunnel handles all players

Players connect to: `your-vps-ip:7777`
