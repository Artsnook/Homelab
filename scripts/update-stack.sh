#!/bin/sh
# Extract Docker images from docker-compose.yml, pull them, restart the stack, and return to the script's directory
# Usage: ./update_stack.sh -s [stack_dir]

# --- Remember the directory where the script was started ---
START_DIR="$(pwd)"

# --- Parse command-line arguments ---
while getopts s: flag
do
    case "${flag}" in
        s) STACK_DIR=${OPTARG};;
    esac
done

# Default to current directory if no stack_dir is provided
STACK_DIR="${STACK_DIR:-.}"
COMPOSE_FILE="$STACK_DIR/docker-compose.yml"

# --- Check for Docker Compose command ---
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ Docker Compose not found"
    exit 1
fi
echo "🧩 Using Docker Compose command: '$COMPOSE_CMD'"

# --- Validate path/file ---
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found in: $STACK_DIR"
    exit 1
fi

echo "🐳 Extracting Docker images from $COMPOSE_FILE"

# --- Extract non-commented image lines ---
IMAGES=$(grep -E '^[[:space:]]*image:' "$COMPOSE_FILE" | grep -v '^[[:space:]]*#' | awk '{print $2}')

if [ -z "$IMAGES" ]; then
    echo "⚠️  No images found in $COMPOSE_FILE"
    exit 0
fi

echo
echo "🔎 Found Docker images:"
echo "$IMAGES"

echo
echo "📦 Pulling latest versions of images..."
for IMAGE in $IMAGES; do
    echo "Pulling $IMAGE ..."
    docker pull "$IMAGE"
done

echo
echo "🔁 Restarting Docker Compose stack..."
cd "$STACK_DIR" || exit 1

echo "⏹️ Bringing down existing containers..."
$COMPOSE_CMD down

echo "▶️ Starting containers in detached mode..."
$COMPOSE_CMD up -d

echo "♻️ Cleaning up Docker resources..."
docker image prune -f

# --- Return to original directory ---
cd "$START_DIR" || exit 1
echo
echo "✅ Done! All images updated, stack restarted, and returned to: $START_DIR"
