#!/bin/sh

set -e

if [ -z "${FILE_URL}" ]; then
  echo "You need to set the FILE_URL environment variable."
  exit 1
fi

if [ -z "${DATABASE_USER}" ]; then
  echo "You need to set the DATABASE_USER environment variable."
  exit 1
fi

if [ -z "${DATABASE_PASSWORD}" ]; then
  echo "You need to set the DATABASE_PASSWORD environment variable."
  exit 1
fi

if [ -z "${DATABASE_HOST}" ]; then
  echo "You need to set the DATABASE_HOST environment variable."
  exit 1
fi

if [ -z "${DATABASE_PORT}" ]; then
  echo "You need to set the DATABASE_PORT environment variable."
  exit 1
fi

# Build the connection URI. READ_PREFERENCE is optional:
#   - leave empty for a standalone mongod (default driver behavior)
#   - set to "secondaryPreferred" (or "secondary") for replica sets
mongo_uri="mongodb://${DATABASE_USER}:${DATABASE_PASSWORD}@${DATABASE_HOST}:${DATABASE_PORT}/"
if [ -n "${READ_PREFERENCE}" ]; then
    mongo_uri="${mongo_uri}?readPreference=${READ_PREFERENCE}"
fi

backup_dir="/tmp/restore"
rm -rf "$backup_dir"
mkdir -p "$backup_dir"

echo "Downloading the file..."
wget -O /tmp/backup.zip "${FILE_URL}"

echo "Unzipping the archive..."
unzip -o /tmp/backup.zip -d "$backup_dir" >/dev/null

# The backup zip from baka-mongo contains a single top-level directory
# named after the source database, with mongodump output (.bson +
# .metadata.json) inside.
src_db_dir=""
for d in "$backup_dir"/*/; do
    if ls "$d"*.bson >/dev/null 2>&1; then
        src_db_dir="${d%/}"
        break
    fi
done

if [ -z "$src_db_dir" ]; then
    echo "Could not find any dumped collections (.bson) in the archive."
    exit 1
fi

src_db_name=$(basename "$src_db_dir")
target_db="${DATABASE_NAME:-$src_db_name}"

echo "Starting restoring of ${src_db_name} into ${target_db} on ${DATABASE_HOST}..."
mongorestore --authenticationDatabase=admin --uri="$mongo_uri" \
    --db "$target_db" --drop "$src_db_dir"
echo "Restoring of ${target_db} on ${DATABASE_HOST} is done!"

export MONGO_URI="$mongo_uri"
export TARGET_DB="$target_db"

if [ "${IS_AUDIT}" = "true" ]; then
    echo "Auditing the database..."
    python /audit.py
    echo "Database ${target_db} is audited!"
fi

if [ "${REMOVE_DATABASE}" = "true" ]; then
    echo "Removing the database..."
    python -c "
import os
from pymongo import MongoClient
MongoClient(os.environ['MONGO_URI']).drop_database(os.environ['TARGET_DB'])
print(f\"Database {os.environ['TARGET_DB']} is removed!\")
"
fi

exit 0
