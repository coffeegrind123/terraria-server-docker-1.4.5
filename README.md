# Terraria Server

Dockerized Terraria dedicated server

## Quick Start

### Prerequisites
1. **Docker & Docker Compose** - Installed on your local machine

### Configuration

Edit `docker-compose.yml`:

Terraria server settings:

```yaml
terraria:
  environment:
    - TERRARIA_MAXPLAYERS=8
    - TERRARIA_AUTOCREATE=3        # 1=Small, 2=Medium, 3=Large
    - TERRARIA_DIFFICULTY=0         # 0=Normal, 1=Expert, 2=Master, 3=Journey
    - TERRARIA_PASSWORD=           # Leave empty for no password
    - TERRARIA_WORLDNAME=world
```

## Commands

```bash
# Start
docker-compose up -d

# View logs
docker-compose logs -f

# View Terraria logs
docker-compose logs -f terraria

# Stop
docker-compose down

# Restart
docker-compose restart
```

## World Management

**Autocreate behavior:**
- First run: Creates new world
- Restarts: Reuses existing world (in `./world/` directory)

**Force new world:**
```bash
docker-compose down
rm ./world/world.wld
docker-compose up -d
```

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

- [Terraria](https://terraria.org)
- [TShock](https://tshock.co/)
