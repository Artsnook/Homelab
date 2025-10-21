#!/bin/sh
# Restore a Docker Compose stack from a backup archive and start it
# Usage: ./restore_stack.sh -f [backup_filename]

# Remember original directory
START_DIR="$(pwd)"

# Parse command-line arguments
while getopts f: flag
do
    case "${flag}" in
        f) BACKUP_FILE=${OPTARG};;
    esac
done

# Validate input
if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not specified or does not exist. Aborting."
    exit 1
fi

# Derive stack directory from filename
# Strip path and extension
STACK_BASENAME=$(basename "$BACKUP_FILE" .tar.gz)
# Remove trailing timestamp: last dash followed by 14 digits
STACK_DIR=$(echo "$STACK_BASENAME" | sed -E 's/-(20[0-9]{12})$//')

echo "📂 Restoring backup file: $BACKUP_FILE"
echo "📦 Target stack directory: $STACK_DIR"

# Create stack directory if it doesn't exist
if [ ! -d "$STACK_DIR" ]; then
    echo "🛠️  Stack directory does not exist. Creating: $STACK_DIR"
    mkdir -p "$STACK_DIR" || { echo "❌ Failed to create stack directory: $STACK_DIR"; exit 1; }
else
    echo "📁 Stack directory exists: $STACK_DIR"
fi

# Extract backup
echo "💾 Extracting backup..."
tar --same-owner --same-permissions -xzvf "$BACKUP_FILE" -C "$STACK_DIR" || { echo "❌ Failed to extract backup"; exit 1; }

# Check for Docker Compose command
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ Docker Compose not found. Cannot start stack."
    exit 1
fi
echo "🧩 Using Docker Compose command: '$COMPOSE_CMD'"

# Change to stack directory
cd "$STACK_DIR" || { echo "❌ Failed to enter stack directory: $STACK_DIR"; exit 1; }

# Start stack
echo "🚀 Starting Docker Compose stack..."
$COMPOSE_CMD up -d || { echo "❌ Failed to start Docker Compose stack"; exit 1; }

# Return to original directory
cd "$START_DIR" || exit 1
echo "✅ Stack restored and started successfully. Returned to: $START_DIR"
