#!/bin/sh

set -e

if [ -z "${AWS_BUCKET}" ]; then
  echo "You need to set the AWS_BUCKET environment variable."
  exit 1
fi

if [ -z "${BUCKET_PREFIX}" ]; then
  echo "You need to set the PREFIX environment variable."
  exit 1
fi

# Check if AWS_ACCESS_KEY_ID is empty
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "AWS_ACCESS_KEY_ID is empty. Updating ~/.s3cfg..."

    # Create or update ~/.s3cfg with empty values
    cat > ~/.s3cfg <<EOL
[default]
access_key =
secret_key =
security_token =
bucket_location = ${AWS_REGION}
EOL
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

if [ -z "${STORAGE_CLASS}" ]; then
  export STORAGE_CLASS="ONEZONE_IA"
fi

# Set the directory where you want to store the dump files
backup_dir="/tmp"

#databases=$(mongo --host $DATABASE_HOST --port $DATABASE_PORT --username $DATABASE_USER --password $DATABASE_PASSWORD --quiet --eval "db.adminCommand('listDatabases').databases.forEach(function(d){print(d.name)})")
output=$(python list_database.py)

# Print the output
echo "Output captured into shell variable:"

# Get the current date
current_date=$(date +"%Y/%m/%d")

# Throw error if no databases are found
if [ -z "$output" ]; then
    echo "No databases found to backup"
    exit 1
fi

# Build the connection URI. READ_PREFERENCE is optional:
#   - leave empty for a standalone mongod (default driver behavior)
#   - set to "secondaryPreferred" (or "secondary") for replica sets to
#     avoid CursorNotFound errors caused by primary-side cursor timeouts
mongo_uri="mongodb://${DATABASE_USER}:${DATABASE_PASSWORD}@${DATABASE_HOST}:${DATABASE_PORT}/"
if [ -n "${READ_PREFERENCE}" ]; then
    mongo_uri="${mongo_uri}?readPreference=${READ_PREFERENCE}"
fi

# Optional: bump server-side cursorTimeoutMillis to keep mongodump's
# read cursor alive on huge collections. Default mongod value is
# 600000 (10 min) — set CURSOR_TIMEOUT_MS to e.g. 21600000 (6h) to
# avoid CursorNotFound mid-dump. Requires the DATABASE_USER to have
# the clusterAdmin/hostManager role; on failure we just warn.
if [ -n "${CURSOR_TIMEOUT_MS}" ]; then
    echo "Setting server cursorTimeoutMillis=${CURSOR_TIMEOUT_MS}..."
    MONGO_URI="$mongo_uri" CURSOR_TIMEOUT_MS="$CURSOR_TIMEOUT_MS" python -c "
import os
from pymongo import MongoClient
ms = int(os.environ['CURSOR_TIMEOUT_MS'])
try:
    MongoClient(os.environ['MONGO_URI']).admin.command({'setParameter': 1, 'cursorTimeoutMillis': ms})
    print(f'cursorTimeoutMillis set to {ms} ms')
except Exception as e:
    print(f'WARNING: failed to set cursorTimeoutMillis: {e}')
"
fi

# MONGODUMP_OPTIONS lets you pass extra flags (e.g.
# "--numParallelCollections=1 --gzip") to reduce cursor-idle pressure
# when a single huge collection keeps tripping CursorNotFound.
MONGODUMP_OPTIONS="${MONGODUMP_OPTIONS:-}"

# Loop through each database and dump it to a separate file
echo "$output" | while read -r line; do
    db=$line
    echo "Starting dump of ${db} database(s) from ${DATABASE_HOST}..."
    mongodump --authenticationDatabase=admin --uri="$mongo_uri" --db $db --out $backup_dir/$db ${MONGODUMP_OPTIONS}

    cd $backup_dir/$db
    zip -r "$backup_dir/$db.zip" *
    # Set the S3 key
    if [ -z "${FILE_NAME}" ]; then
        dump_name=$(date +"%Y-%m-%d_%H-%M-%S")
        NAME="${db}_${dump_name}"
    else
        NAME="${FILE_NAME}"
    fi
    s3_key="${BUCKET_PREFIX}/$db/${current_date}/${FILE_NAME}.zip"

    echo "Uploading $db.dump to S3"
    s3cmd --no-mime-magic put $backup_dir/$db.zip s3://${AWS_BUCKET}/$s3_key --storage-class=$STORAGE_CLASS  --add-header="x-amz-meta-backup-at:$(date +"%Y-%m-%d %H-%M-%S")"
    echo "Upload complete for $db.dump to $s3_key"
done

echo "Done!"

exit 0
