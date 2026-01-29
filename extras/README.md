# Terraria Server with FRP Tunnel

Dockerized Terraria dedicated server with FRP integration for NAT traversal and automatic updates.

> **VPS Setup Guide**: See [FRP_SETUP.md](./FRP_SETUP.md) (Debian/Ubuntu) for complete server installation instructions.

## Features

- **Automatic Updates** - Enumerates and installs latest Terraria server on startup, with hourly update checks
- **Remote Commands** - Execute server commands via `docker exec`
- **FRP Tunnel** - Expose server to internet without port forwarding
- **World Persistence** - World data stored in local volume

## Quick Start

### Prerequisites

1. **FRP Server** - You need an FRP server (frps) on a VPS with public IP
2. **Docker & Docker Compose** - Installed on your local machine

### Setup

```bash
# Edit docker-compose.yml and set your FRP server details:
#    - FRP_SERVER_ADDR=your-vps-ip
#    - FRP_TOKEN=your_secure_token

# Start
docker-compose up -d

# View logs
docker-compose logs -f
```

## Configuration

Edit `docker-compose.yml`:

```yaml
frp:
  environment:
    - FRP_SERVER_ADDR=your-vps-ip         # REQUIRED: Your VPS IP
    - FRP_SERVER_PORT=7000                # FRP server port (default)
    - FRP_TOKEN=your_secure_token         # REQUIRED: From VPS setup
    - FRP_LOCAL_PORT=7777                 # Terraria port
    - FRP_REMOTE_PORT=7777                # Port exposed on VPS
```

Terraria server settings:

```yaml
terraria:
  environment:
    - TERRARIA_MAXPLAYERS=8
    - TERRARIA_AUTOCREATE=3        # 1=Small, 2=Medium, 3=Large
    - TERRARIA_DIFFICULTY=0         # 0=Normal, 1=Expert, 2=Master, 3=Journey
    - TERRARIA_PASSWORD=           # Leave empty for no password
    - TERRARIA_WORLDNAME=world     # World name (creates or loads this world)
    - AUTO_UPDATE_ENABLED=1        # Enable automatic updates
```

### Multiple Worlds

The `TERRARIA_WORLDNAME` variable controls which world to load or create:

- **New world name**: Creates a new world with that name
- **Existing world name**: Loads the existing world
- World files are stored in `./world/{WORLDNAME}.wld`

Example configurations:

```yaml
# Creative world
- TERRARIA_WORLDNAME=creative

# Hardcore world
- TERRARIA_WORLDNAME=hardcore

# Custom world path
- TERRARIA_WORLD=/custom/path/myworld.wld
```

## Architecture

```
Internet Players -> VPS (FRP Server) -> Local Terraria (Docker)
                      Port 7777 exposed
```

Players connect to: `your-vps-ip:7777`

The single FRP tunnel handles all players - no per-player tunnels needed.

## Remote Commands

Execute server commands from your host:

```bash
# Show online players
docker exec terraria-server cmd playing

# Save the world
docker exec terraria-server cmd save

# Show help
docker exec terraria-server cmd help
```

## Auto-Update System

When enabled, the container:
1. Checks for updates hourly by enumerating available versions
2. Warns players 2 minutes before restart
3. Saves world and gracefully shuts down
4. Downloads and installs update
5. Restarts server with new version

Update announcements show version numbers: `Update available: v1450 -> v1452`

## World Management

World files persist in `./world/` directory. Each world is named according to `TERRARIA_WORLDNAME`.

**Backup world:**
```bash
tar czf terraria-backup-$(date +%Y%m%d-%H%M).tar.gz ./world
```

**Restore world:**
```bash
docker-compose down
tar xzf terraria-backup-YYYYMMDD-HHMM.tar.gz
docker-compose up -d
```

**Switch to different world:**
```bash
# Edit docker-compose.yml
- TERRARIA_WORLDNAME=adventure

# Restart
docker-compose restart
```

**Force new world:**
```bash
docker-compose down
rm ./world/world.wld
docker-compose up -d
```

## Commands

```bash
# Start
docker-compose up -d

# View Terraria logs
docker-compose logs -f terraria

# View FRP logs
docker-compose logs -f frp

# Stop
docker-compose down

# Restart
docker-compose restart
```

## Server Config (Optional)

For advanced configuration, mount a custom config file:

```yaml
terraria:
  volumes:
    - ./config.json:/terraria/TerrariaServer/Linux/serverconfig.txt:ro
```

Example `config.json`:
```json
{
  "ServerPort": 7777,
  "MaxPlayers": 8,
  "WorldName": "world",
  "Password": "",
  "Motd": "Welcome to my Terraria Server!"
}
```

## Links

- [FRP Documentation](https://github.com/fatedier/frp)
- [Terraria](https://terraria.org)
- [Docker Compose](https://docs.docker.com/compose/)
