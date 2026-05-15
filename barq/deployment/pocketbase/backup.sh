#!/bin/sh
# Nightly PocketBase backup.
# Snapshots data.db + auxiliary.db with SQLite's online .backup command (safe
# while PocketBase is running) and writes a tarball that also includes the
# uploaded files in pb_data/storage. Old archives beyond BACKUP_RETENTION_DAYS
# are pruned.
#
# This container only reads pb_data; the writable target is pb_backups.
set -eu

SRC=/pb/pb_data
DEST=/pb/pb_backups
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-14}

mkdir -p "$DEST"

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Use SQLite .backup so the file is in a consistent state even under load.
for DB in data.db auxiliary.db; do
  if [ -f "$SRC/$DB" ]; then
    sqlite3 "$SRC/$DB" ".backup '$WORK/$DB'"
  fi
done

# Copy uploaded files (license photos, damage photos, national_id).
# These are usually the biggest chunk; rsync would be nicer but we keep this
# image minimal.
if [ -d "$SRC/storage" ]; then
  cp -R "$SRC/storage" "$WORK/storage"
fi

OUT="$DEST/pb_backup_${STAMP}.tar.gz"
tar -C "$WORK" -czf "$OUT" .
echo "$(date -u +%FT%TZ) wrote $OUT ($(du -h "$OUT" | cut -f1))"

# Prune old archives.
find "$DEST" -maxdepth 1 -type f -name 'pb_backup_*.tar.gz' \
  -mtime "+$RETENTION_DAYS" -print -delete
