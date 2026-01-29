#!/bin/bash

# Player Join Announcer
# Monitors server logs for player joins and announces player count

FIFO="/tmp/terraria-commands.fifo"
SERVER_LOG="/tmp/terraria-server-output.log"
ANNOUNCED_PLAYERS="/tmp/announced_players.txt"

# Make sure FIFO exists
if [ ! -p "$FIFO" ]; then
    echo "Error: Server FIFO not found at $FIFO"
    exit 1
fi

# Create file to track announced players
touch "$ANNOUNCED_PLAYERS"

echo -e "${GREEN}[Player Announcer] Started, monitoring for joins...${NC}"

# Track current position in log
if [ -f "$SERVER_LOG" ]; then
    CURRENT_LINE=$(wc -l < "$SERVER_LOG")
else
    CURRENT_LINE=0
fi

while true; do
    # Check if log file exists and has new lines
    if [ -f "$SERVER_LOG" ]; then
        TOTAL_LINES=$(wc -l < "$SERVER_LOG")

        if [ "$TOTAL_LINES" -gt "$CURRENT_LINE" ]; then
            # Read new lines
            NEW_LINES=$(tail -n +$((CURRENT_LINE + 1)) "$SERVER_LOG")
            CURRENT_LINE=$TOTAL_LINES

            # Check for player joins (format: "PlayerName has joined.")
            if echo "$NEW_LINES" | grep -q "has joined\."; then
                JOIN_MESSAGE=$(echo "$NEW_LINES" | grep "has joined\." | tail -1)
                PLAYER_NAME=$(echo "$JOIN_MESSAGE" | sed 's/ has joined\.*//')

                # Check if we already announced this player recently
                if ! grep -q "^$PLAYER_NAME$" "$ANNOUNCED_PLAYERS" 2>/dev/null; then
                    echo -e "${YELLOW}[Player Announcer] $PLAYER_NAME joined, waiting 3s...${NC}"

                    # Wait for player to fully connect
                    sleep 3

                    # Send 'playing' command
                    echo "playing" > "$FIFO"

                    # Wait for response
                    sleep 1

                    # Get new log output to parse player count
                    if [ -f "$SERVER_LOG" ]; then
                        LINES_AFTER_CMD=$(tail -n +$((CURRENT_LINE + 1)) "$SERVER_LOG")

                        # Parse player count from "X player(s) connected." or "No players connected."
                        PLAYER_COUNT=$(echo "$LINES_AFTER_CMD" | grep -oP '\d+(?= player(s)? connected\.)' | head -1)

                        if [ -n "$PLAYER_COUNT" ]; then
                            # Announce player count
                            ANNOUNCEMENT="There are $PLAYER_COUNT player(s) online."
                            echo "say $ANNOUNCEMENT" > "$FIFO"
                            echo -e "${GREEN}[Player Announcer] Announced: $ANNOUNCEMENT${NC}"
                        else
                            # If we couldn't parse, check for "No players connected"
                            if echo "$LINES_AFTER_CMD" | grep -q "No players connected"; then
                                # This shouldn't happen since someone just joined, but handle it
                                ANNOUNCEMENT="$PLAYER_NAME has joined the server!"
                                echo "say $ANNOUNCEMENT" > "$FIFO"
                                echo -e "${GREEN}[Player Announcer] Announced: $ANNOUNCEMENT${NC}"
                            fi
                        fi

                        # Update current line position
                        CURRENT_LINE=$(wc -l < "$SERVER_LOG")
                    fi

                    # Mark this player as announced (clear old entries, keep last 10)
                    echo "$PLAYER_NAME" >> "$ANNOUNCED_PLAYERS"
                    tail -10 "$ANNOUNCED_PLAYERS" > "${ANNOUNCED_PLAYERS}.tmp"
                    mv "${ANNOUNCED_PLAYERS}.tmp" "$ANNOUNCED_PLAYERS"

                    # Wait a bit before announcing again
                    sleep 5
                fi
            fi
        fi
    fi

    # Sleep briefly to avoid high CPU usage
    sleep 0.5
done
