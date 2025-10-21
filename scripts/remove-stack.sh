#!/bin/sh
# Stop and remove a Docker Compose stack and delete its directory
# Usage: ./remove-stack.sh -s [stack_directory]

# --- Remember original directory ---
START_DIR="$(pwd)"

# --- Parse command-line arguments ---
while getopts s: flag
do
    case "${flag}" in
        s) STACK_DIR=${OPTARG};;
    esac
done

# --- Validate input ---
if [ -z "$STACK_DIR" ]; then
    echo "❌ Stack directory not specified. Aborting."
    exit 1
fi

if [ ! -d "$STACK_DIR" ]; then
    echo "⚠️  Stack directory does not exist: $STACK_DIR. Nothing to remove."
    exit 0
fi

echo "📦 Removing stack: $STACK_DIR"

# --- Check for Docker Compose command ---
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ Docker Compose not found. Cannot stop stack."
    exit 1
fi
echo "🧩 Using Docker Compose command: '$COMPOSE_CMD'"

# --- Change to stack directory ---
cd "$STACK_DIR" || { echo "❌ Failed to enter stack directory: $STACK_DIR"; exit 1; }

# --- Stop Docker Compose stack ---
echo "⏹️  Stopping Docker Compose stack..."
$COMPOSE_CMD down || { echo "⚠️ Failed to stop stack or it may not be running"; }

# --- Return to original directory ---
cd "$START_DIR" || exit 1

# --- Remove stack directory ---
echo "🗑️  Removing stack directory: $STACK_DIR"
rm -rf "$STACK_DIR" || { echo "❌ Failed to remove stack directory"; exit 1; }

echo "✅ Stack removed successfully: $STACK_DIR"
