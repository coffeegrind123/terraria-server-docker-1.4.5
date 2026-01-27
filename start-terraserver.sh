#!/bin/bash

# Terraria Server Startup Script for Docker

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting Terraria Server...${NC}"

# Set defaults from environment variables
PORT=${TERRARIA_PORT:-7777}
MAXPLAYERS=${TERRARIA_MAXPLAYERS:-8}
WORLDNAME=${TERRARIA_WORLDNAME:-world}
WORLDPATH=${TERRARIA_WORLD:-/terraria/world/${WORLDNAME}.wld}
AUTOCREATE=${TERRARIA_AUTOCREATE:-1}
DIFFICULTY=${TERRARIA_DIFFICULTY:-0}
PASSWORD=${TERRARIA_PASSWORD:-}
MOTD=${TERRARIA_MOTD:-"Welcome to the Terraria Server!"}
SEED=${TERRARIA_SEED:-}

# Create world directory if it doesn't exist
mkdir -p /terraria/world
mkdir -p /terraria/logs

# Check if config file is mounted or exists
CONFIG_FILE="/terraria/TerrariaServer/Linux/serverconfig.txt"

# Check if world file already exists
if [ -f "$WORLDPATH" ]; then
    echo -e "${GREEN}Found existing world: $WORLDPATH${NC}"
    WORLD_EXISTS=true
else
    echo -e "${YELLOW}No world found at: $WORLDPATH${NC}"
    WORLD_EXISTS=false
fi

# Build Terraria server command
SERVER_CMD="mono /terraria/TerrariaServer/Linux/TerrariaServer.exe"

# Add command line arguments
SERVER_CMD="$SERVER_CMD -port $PORT"
SERVER_CMD="$SERVER_CMD -maxplayers $MAXPLAYERS"
SERVER_CMD="$SERVER_CMD -world \"$WORLDPATH\""

# Only add -autocreate if world doesn't exist
if [ "$WORLD_EXISTS" = false ]; then
    echo -e "${YELLOW}Will autocreate new world (size: $AUTOCREATE)${NC}"
    SERVER_CMD="$SERVER_CMD -autocreate $AUTOCREATE"
else
    echo -e "${GREEN}Skipping autocreate, using existing world${NC}"
fi

SERVER_CMD="$SERVER_CMD -worldname \"$WORLDNAME\""
SERVER_CMD="$SERVER_CMD -difficulty $DIFFICULTY"

if [ -n "$PASSWORD" ]; then
    SERVER_CMD="$SERVER_CMD -password \"$PASSWORD\""
fi

if [ -n "$MOTD" ]; then
    SERVER_CMD="$SERVER_CMD -motd \"$MOTD\""
fi

if [ -n "$SEED" ]; then
    SERVER_CMD="$SERVER_CMD -seed \"$SEED\""
fi

# Use config file if it exists and has content
if [ -s "$CONFIG_FILE" ]; then
    echo -e "${GREEN}Using config file: $CONFIG_FILE${NC}"

    # If using config file and world exists, remove -autocreate from config to prevent recreation
    if [ "$WORLD_EXISTS" = true ]; then
        echo -e "${GREEN}World exists, disabling autocreate in config${NC}"
        # Create a temp config without autocreate
        sed 's/-autocreate [0-9]//g' "$CONFIG_FILE" > /tmp/serverconfig.txt 2>/dev/null || cp "$CONFIG_FILE" /tmp/serverconfig.txt
        SERVER_CMD="mono /terraria/TerrariaServer/Linux/TerrariaServer.exe -config \"/tmp/serverconfig.txt\""
    else
        SERVER_CMD="mono /terraria/TerrariaServer/Linux/TerrariaServer.exe -config \"$CONFIG_FILE\""
    fi
else
    echo -e "${YELLOW}No config file found, using command line arguments${NC}"
fi

# Print configuration
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Terraria Server Configuration${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Port: ${PORT}"
echo -e "Max Players: ${MAXPLAYERS}"
echo -e "World: ${WORLDPATH}"
echo -e "World Exists: $WORLD_EXISTS"
echo -e "World Name: ${WORLDNAME}"
if [ "$WORLD_EXISTS" = false ]; then
    echo -e "Auto Create: ${AUTOCREATE} (world will be created)"
else
    echo -e "Auto Create: ${AUTOCREATE} (skipped, using existing world)"
fi
echo -e "Difficulty: ${DIFFICULTY}"
echo -e "${GREEN}========================================${NC}"

# Change to server directory
cd /terraria/TerrariaServer/Linux

# Start server (eval to handle quotes properly)
eval $SERVER_CMD
