#!/bin/bash

# Terraria Auto-Update Checker
# Runs in background, checks for updates hourly, handles graceful restarts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check interval: 2 minutes in DEBUG mode, 1 hour normally
# if [ "$DEBUG" = "1" ]; then
#     CHECK_INTERVAL=120  # 2 minutes for testing
# else
    CHECK_INTERVAL=3600  # 1 hour
# fi
SERVER_PID_FILE="/tmp/terraria-server.pid"
CURRENT_VERSION_FILE="/tmp/terraria-version.txt"

# Get current installed version
get_current_version() {
    if [ -f "$CURRENT_VERSION_FILE" ]; then
        cat "$CURRENT_VERSION_FILE"
    else
        echo "1452"
    fi
}

# Find latest available version using same mechanism as Dockerfile
find_latest_version() {
    local version=1452
    while true; do
        next_version=$((version + 1))
        if curl -sI "https://terraria.org/api/download/pc-dedicated-server/terraria-server-$next_version.zip" | grep -q "HTTP.*200"; then
            version=$next_version
        else
            break
        fi
    done
    echo "$version"
}

# Send message to Terraria server console
send_server_message() {
    local message="$1"
    local pid
    pid=$(cat "$SERVER_PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        # Send "say" command to server via stdin if possible
        # This requires the server to be running with input redirection
        echo "say $message" > "/tmp/terraria-commands.fifo" 2>/dev/null || \
        echo -e "${YELLOW}[UPDATE] $message${NC}"
    else
        echo -e "${YELLOW}[UPDATE] $message${NC}"
    fi
}

# Download and install update
install_update() {
    local new_version="$1"
    echo -e "${BLUE}Downloading Terraria server $new_version...${NC}"

    cd /terraria

    # Download new version
    curl -O "https://terraria.org/api/download/pc-dedicated-server/terraria-server-$new_version.zip" || {
        echo -e "${RED}Failed to download update${NC}"
        return 1
    }

    # Extract to temp location
    mkdir -p /tmp/terraria-update
    unzip -q "terraria-server-$new_version.zip" -d /tmp/terraria-update/ || {
        echo -e "${RED}Failed to extract update${NC}"
        rm -f "terraria-server-$new_version.zip"
        return 1
    }

    # Move current server to backup
    mv TerrariaServer "TerrariaServer.old.$(date +%s)" || {
        echo -e "${RED}Failed to backup old server${NC}"
        rm -f "terraria-server-$new_version.zip"
        rm -rf /tmp/terraria-update
        return 1
    }

    # Install new server
    mv "/tmp/terraria-update/$new_version" TerrariaServer || {
        echo -e "${RED}Failed to install new server${NC}"
        # Attempt to restore backup
        mv "TerrariaServer.old."* TerrariaServer
        rm -f "terraria-server-$new_version.zip"
        rm -rf /tmp/terraria-update
        return 1
    }

    # Clean up temporary files
    rm -f "terraria-server-$new_version.zip"
    rm -rf /tmp/terraria-update

    # Clean up unnecessary files from new installation
    rm -f TerrariaServer/Linux/System*
    rm -f TerrariaServer/Linux/Mono*
    rm -f TerrariaServer/Linux/monoconfig
    rm -f TerrariaServer/Linux/mscorlib.dll
    rm -rf TerrariaServer/Mac
    rm -rf TerrariaServer/Windows

    # Make server executable
    chmod +x TerrariaServer/Linux/TerrariaServer*

    # Update version file
    echo "$new_version" > "$CURRENT_VERSION_FILE"

    echo -e "${GREEN}Update to version $new_version completed successfully!${NC}"
    return 0
}

# Perform update with countdown
do_update() {
    local new_version="$1"
    local current_version=$(get_current_version)

    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}UPDATE AVAILABLE: $current_version → $new_version${NC}"
    echo -e "${YELLOW}========================================${NC}"

    # Initial in-game announcement - 2 minutes
    send_server_message "Update available: v$current_version → v$new_version. Restarting in 2 minutes."

    # Log-only countdown from 120s to 35s
    for i in 115 110 105 100 95 90 85 80 75 70 65 60 55 50 45 40 35; do
        sleep 5
        echo -e "${YELLOW}[UPDATE] Restarting in $i seconds...${NC}"
    done

    # Final 30 seconds - in-game countdown every 5 seconds
    for i in 30 25 20 15 10 5; do
        sleep 5
        send_server_message "Restarting in $i seconds"
    done

    # Final countdown - in-game
    for i in 5 4 3 2 1; do
        sleep 1
        send_server_message "Restarting in $i..."
    done

    # Gracefully exit server (saves world automatically)
    echo -e "${YELLOW}[UPDATE] Sending exit command to server...${NC}"
    echo "exit" > /tmp/terraria-commands.fifo

    # Create lock file to prevent init from restarting during update
    touch /tmp/updating.lock

    # Wait for server to gracefully exit and save
    echo -e "${YELLOW}[UPDATE] Waiting for server to exit...${NC}"
    sleep 5

    # Verify server is stopped
    pid=$(cat "$SERVER_PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo -e "${RED}[UPDATE] Server didn't exit gracefully, forcing...${NC}"
        pkill -9 -f "TerrariaServer.exe" || true
        pkill -9 -f "mono TerrariaServer" || true
        kill -9 "$pid" 2>/dev/null || true
        sleep 2
    fi

    echo -e "${GREEN}[UPDATE] Server stopped${NC}"
    echo -e "${BLUE}[UPDATE] Downloading and installing update...${NC}"

    # Install update
    if install_update "$new_version"; then
        echo -e "${GREEN}[UPDATE] Update complete! Waiting for server restart...${NC}"

        # Remove lock file so init can restart the server
        rm -f /tmp/updating.lock

        # Wait for init script to detect server stopped and restart it
        sleep 10
    else
        echo -e "${RED}Update failed, manual intervention required${NC}"
        exit 1
    fi
}

# Main update check loop
update_loop() {
    echo -e "${GREEN}[UPDATE] Auto-update checker started, checking every hour${NC}"

    while true; do
        sleep "$CHECK_INTERVAL"

        current_version=$(get_current_version)
        echo -e "${BLUE}[UPDATE] Checking for updates (current: $current_version)...${NC}"

        latest_version=$(find_latest_version)

        if [ "$latest_version" != "$current_version" ]; then
            echo -e "${YELLOW}[UPDATE] New version available: $latest_version${NC}"
            do_update "$latest_version"
            break
        else
            echo -e "${GREEN}[UPDATE] Already on latest version: $current_version${NC}"
        fi
    done
}

# Save server PID for later use
save_server_pid() {
    echo "$1" > "$SERVER_PID_FILE"
}

# Main entry point
case "$1" in
    --save-pid)
        save_server_pid "$2"
        ;;
    --check)
        # Single check (for testing)
        current=$(get_current_version)
        latest=$(find_latest_version)
        echo "Current: $current, Latest: $latest"
        if [ "$latest" != "$current" ]; then
            echo "Update available!"
            exit 1
        fi
        ;;
    *)
        update_loop
        ;;
esac
