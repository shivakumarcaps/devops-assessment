#!/usr/bin/env bash
set -euo pipefail
FILE="${1:-$(ls -t backups/*.sql | head -1)}"
NEW_DB="hotel_restore"
echo "Restoring from: $FILE"
docker compose exec -T db psql -U app -d postgres -c "DROP DATABASE IF EXISTS ${NEW_DB};"
docker compose exec -T db psql -U app -d postgres -c "CREATE DATABASE ${NEW_DB};"
docker compose exec -T db psql -U app -d "${NEW_DB}" < "$FILE"
echo "Row counts in restored DB:"
docker compose exec -T db psql -U app -d "${NEW_DB}" -c \
  "SELECT 'hotel_bookings' AS tbl, COUNT(*) FROM hotel_bookings
   UNION ALL
   SELECT 'booking_events', COUNT(*) FROM booking_events;"
