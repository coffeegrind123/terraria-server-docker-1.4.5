# Terraria Server

Dockerized Terraria dedicated server with automatic updates and player count announcements upon joining.

## Features

- **Automatic Updates** - Enumerates and installs latest Terraria server on startup, with hourly update checks
- **Player Count Announcements** - Automatically announces player count when someone joins
- **Remote Commands** - Execute server commands via `docker exec` eq. `docker exec cmd playing` to list online players
- **World Persistence** - World data stored in local volume

## Quick Start

```bash
# Clone repository
git clone https://github.com/coffeegrind123/terraria-server-docker-1.4.5.git
cd terraria-server-docker-1.4.5

# Start server
docker-compose up -d

# View logs
docker-compose logs -f
```

## Configuration

Edit `docker-compose.yml`:

```yaml
terraria:
  environment:
    - TERRARIA_MAXPLAYERS=8
    - TERRARIA_AUTOCREATE=3        # 1=Small, 2=Medium, 3=Large
    - TERRARIA_DIFFICULTY=0         # 0=Normal, 1=Expert, 2=Master, 3=Journey
    - TERRARIA_PASSWORD=           # Leave empty for no password
    - TERRARIA_WORLDNAME=world     # World name (creates or loads this world)
    - AUTO_UPDATE_ENABLED=1        # Enable automatic updates
    - ANNOUNCE_PLAYERS=1           # Enable player count announcements on player join
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
2. Warns players 2 minutes in advance and also the final 30 seconds before restart
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
OR change `TERRARIA_WORLDNAME`:
```bash
- TERRARIA_WORLDNAME=namehere
```

## Commands

```bash
# Start
docker-compose up -d

# View logs
docker-compose logs -f terraria

# Stop
docker-compose down

# Restart
docker-compose restart

# Force a clean rebuild and restart
docker compose build --no-cache; docker compose up -d
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

## FRP Tunneling Support

To enable FRP tunneling for remote access behind NAT/firewalls:

```bash
cp -f extras/frp.docker-compose.yml docker-compose.yml
cp -f extras/Dockerfile.frp .
```

See [extras/README.md](extras/README.md) for detailed setup instructions.

## Links

- [Terraria](https://terraria.org)
- [Docker Compose](https://docs.docker.com/compose/)
