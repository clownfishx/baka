#!/bin/sh

set -e

export PGUSER="${DATABASE_USER}"
export PGPASSWORD="${DATABASE_PASSWORD}"
export PGHOST="${DATABASE_HOST}"
export PGPORT="${DATABASE_PORT}"

if [ -z "${AWS_BUCKET}" ]; then
  echo "You need to set the AWS_BUCKET environment variable."
  exit 1
fi

if [ -z "${BUCKET_PREFIX}" ]; then
  echo "You need to set the PREFIX environment variable."
  exit 1
fi

if [ -z "${PGUSER}" ]; then
  echo "You need to set the PGUSER environment variable."
  exit 1
fi

if [ -z "${PGPASSWORD}" ]; then
  echo "You need to set the PGPASSWORD environment variable."
  exit 1
fi

if [ -z "${PGHOST}" ]; then
  echo "You need to set the PGHOST environment variable."
  exit 1
fi

if [ -z "${STORAGE_CLASS}" ]; then
  export STORAGE_CLASS="ONEZONE_IA"
fi

export DEFAULT_IGNORE_DATABASES="postgres,template0,template1"

if [ -z "${IGNORE_DATABASES}" ]; then
    export IGNORE_DATABASES="$DEFAULT_IGNORE_DATABASES"
else
    export IGNORE_DATABASES="${IGNORE_DATABASES},${DEFAULT_IGNORE_DATABASES}"
fi

IGNORE_DATABASES=$(echo "$IGNORE_DATABASES" | sed "s/\([^,]*\)/'\1'/g")

# Set the directory where you want to store the dump files
backup_dir="/tmp"

if [ -n "${DATABASE_NAME}" ]; then
  database_list=$(psql -q -A -t -c "SELECT datname FROM pg_database WHERE datname = '${DATABASE_NAME}'")
else
  database_list=$(psql -q -A -t -c "SELECT datname FROM pg_database WHERE datname NOT IN (${IGNORE_DATABASES})")
fi

# Get a list of databases
databases=$(echo $database_list | cut -d \| -f 1)

# Get the current date
current_date=$(date +"%Y/%m/%d")

# throw error if no databases are found
if [ -z "$databases" ]; then
    echo "No databases found to backup"
    exit 1
fi

# Loop through each database and dump it to a separate file
for db in $databases; do
    echo "Starting dump of ${db} database(s) from ${PGHOST}..."
    pg_dump -Fc --no-acl --no-owner "$db" > $backup_dir/$db.dump
    # Set the S3 key
    if [ -z "${FILE_NAME}" ]; then
        dump_name=$(date +"%Y-%m-%d_%H-%M-%S")
        FILE_NAME="${db}_${dump_name}"
    fi
    s3_key="${BUCKET_PREFIX}/$db/${current_date}/${FILE_NAME}.dump"

    echo "Uploading $db.dump to S3"
    s3cmd --no-mime-magic put $backup_dir/$db.dump s3://${AWS_BUCKET}/$s3_key --storage-class=$STORAGE_CLASS
    echo "Upload complete for $db.dump to $s3_key"
done

echo "Done!"

exit 0
