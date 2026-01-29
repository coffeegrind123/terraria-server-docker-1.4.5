#!/bin/bash

# Terraria Server Command Executor (runs inside container)
# Usage: docker exec terraria-server cmd <command>

FIFO="/tmp/terraria-commands.fifo"
SERVER_LOG="/tmp/terraria-server-output.log"

if [ ! -p "$FIFO" ]; then
    echo "Error: Server FIFO not found at $FIFO"
    echo "Is the server running?"
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: $0 <command>"
    exit 1
fi

# Join all arguments with spaces
COMMAND="$*"

# Get current line count before sending command
if [ -f "$SERVER_LOG" ]; then
    START_LINE=$(wc -l < "$SERVER_LOG")
else
    START_LINE=0
fi

# Send command to server
echo "$COMMAND" > "$FIFO"

# Wait for command to process
sleep 1

# Show only new lines after the command
if [ -f "$SERVER_LOG" ]; then
    CURRENT_LINES=$(wc -l < "$SERVER_LOG")
    if [ "$CURRENT_LINES" -gt "$START_LINE" ]; then
        tail -n +$((START_LINE + 1)) "$SERVER_LOG"
    fi
fi
