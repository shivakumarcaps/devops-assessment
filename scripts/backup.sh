#!/usr/bin/env bash
set -euo pipefail
mkdir -p backups
TS=$(date +%Y%m%d_%H%M%S)
FILE="backups/hotel_${TS}.sql"
docker compose exec -T db pg_dump -U app -d hotel > "$FILE"
echo "Backup created: $FILE"
