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

if [ -z "${PGDATABASE}" ]; then
  echo "You need to set the PGDATABASE environment variable."
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

# Set the directory where you want to store the dump files
backup_dir="/tmp"

database_list=$(psql -q -A -t -c "SELECT datname FROM pg_database where datname not in ('postgres', 'template1', 'template0')")
# Get a list of databases
databases=$(echo $database_list | cut -d \| -f 1)

# Get the current date
current_date=$(date +"%Y/%m/%d")

# Loop through each database and dump it to a separate file
for db in $databases; do
    echo "Starting dump of ${db} database(s) from ${PGHOST}..."
    pg_dump -Fc --no-acl --no-owner $db > $backup_dir/$db.dump
    # Set the S3 key
    dump_name=$(date +"%Y-%m-%d_%H-%M-%S")
    s3_key="${BUCKET_PREFIX}/$db/${current_date}/${db}_${dump_name}.dump"

    echo "Uploading $db.dump to S3"
    s3cmd put $backup_dir/$db.dump s3://${AWS_BUCKET}/$s3_key
    echo "Upload complete for $db.dump to $s3_key"
done

echo "Done!"

exit 0
