#!/bin/sh
# Backup a Docker Compose stack, stop/start containers, and save a timestamped archive
# Usage: ./backup_stack.sh -s [stack_directory]

# Get the hostname
HOSTNAME=$(hostname)
echo "🏠 Running backup on host: $HOSTNAME"

# --- Backup settings ---
BACKUP_TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_PATH="/mnt/nfs_backup/Docker/${HOSTNAME}"
MAX_BACKUPS=3

# --- Check for Docker Compose command ---
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ Docker Compose not found"
    exit 1
fi
echo "🧩 using: '$COMPOSE_CMD'"

# Ensure backup directory exists
if [ ! -d "$BACKUP_PATH" ]; then
    echo "🛠️  Backup path does not exist. Creating: $BACKUP_PATH"
    mkdir -p "$BACKUP_PATH" || { echo "❌ Failed to create backup path: $BACKUP_PATH"; exit 1; }
else
    echo "📁 Backup path exists: $BACKUP_PATH"
fi

# Remember the original directory
START_DIR="$(pwd)"

# Parse command-line arguments
while getopts s: flag
do
    case "${flag}" in
        s) STACK_DIR=${OPTARG};;
    esac
done

# Determine stack directory
if [ -z "$STACK_DIR" ]; then
    echo "⚠️  No stack specified. Using current directory as stack."
    STACK_DIR="${PWD##*/}"
    STACK_PATH="$PWD"
else
    echo "📦 Backing up stack: $STACK_DIR"
    STACK_PATH="$STACK_DIR"
fi

# Change to stack directory if needed
if [ "$STACK_PATH" != "$PWD" ]; then
    cd "$STACK_PATH" || { echo "❌ Failed to enter stack directory: $STACK_PATH"; exit 1; }
fi

# --- Check if the stack is currently running ---
echo "🔎 Checking if Docker Compose stack is running..."
if $COMPOSE_CMD ps -q | grep -q .; then
    STACK_RUNNING=true
    echo "✅ Stack is running. Will restart after backup."
else
    STACK_RUNNING=false
    echo "⚠️  Stack is not running. Will not start after backup."
fi

# Stop Docker Compose stack (only if any containers exist)
echo "⏹️  Stopping Docker Compose stack..."
$COMPOSE_CMD down

# --- Determine backup filename ---
BACKUP_FILENAME="${BACKUP_PATH}/${STACK_DIR}-${BACKUP_TIMESTAMP}.tar.gz"

# Create backup archive
echo "💾 Creating backup: $BACKUP_FILENAME"
# Uncomment --exclude lines if needed
# tar --exclude='./deps' --exclude='*.log' --exclude='*.db' --exclude='.HA_VERSION' -zcvf "$BACKUP_FILENAME" .
tar -zcvf "$BACKUP_FILENAME" .

# --- Restart stack only if it was running ---
if [ "$STACK_RUNNING" = true ]; then
    echo "🚀 Starting Docker Compose stack..."
    $COMPOSE_CMD up -d
fi

# --- Cleanup old backups ---
echo "🧹 Enforcing maximum of $MAX_BACKUPS backups..."

# Find all backups for this stack, newest first, safely handle spaces
BACKUP_FILES=$(find "$BACKUP_PATH" -maxdepth 1 -type f -name "${STACK_DIR}-*.tar.gz" -printf "%T@ %p\n" | sort -n -r | awk '{print substr($0, index($0,$2))}')

# Convert to an array-like list
BACKUP_ARRAY=$(printf "%s\n" "$BACKUP_FILES")

# Count backups
BACKUP_COUNT=$(echo "$BACKUP_ARRAY" | wc -l)
echo "📊 Found $BACKUP_COUNT backup(s) for stack: $STACK_DIR"

if [ "$BACKUP_COUNT" -le "$MAX_BACKUPS" ] || [ -z "$BACKUP_ARRAY" ]; then
    echo "✅ No old backups to delete."
else
    TO_DELETE=$((BACKUP_COUNT - MAX_BACKUPS))
    echo "🗑️  Deleting $TO_DELETE old backup(s)..."

    # Use a safe loop to delete old backups
    i=0
    printf "%s\n" "$BACKUP_ARRAY" | tac | while IFS= read -r OLD_BACKUP; do
        i=$((i+1))
        if [ "$i" -le "$TO_DELETE" ]; then
            echo "Deleting: $OLD_BACKUP"
            rm -f "$OLD_BACKUP"
        fi
    done
fi

# Return to original directory
cd "$START_DIR" || exit 1
echo "✅ Backup completed and returned to: $START_DIR"
