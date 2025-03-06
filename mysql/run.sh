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

if [ -z "${STORAGE_CLASS}" ]; then
  export STORAGE_CLASS="ONEZONE_IA"
fi

export DEFAULT_IGNORE_DATABASES="Database|information_schema|performance_schema|mysql|sys"

if [ -z "${IGNORE_DATABASES}" ]; then
    export IGNORE_DATABASES="$DEFAULT_IGNORE_DATABASES"
else
    export IGNORE_DATABASES="${IGNORE_DATABASES}|${DEFAULT_IGNORE_DATABASES}"
fi

IGNORE_DATABASES=$(echo "$IGNORE_DATABASES" | sed "s/,/|/g")

# Set the directory where you want to store the dump files
backup_dir="/tmp"

# Get a list of MySQL databases, excluding system databases
database_list=$(mariadb -h "${DATABASE_HOST}" -u "${DATABASE_USER}" -p"${DATABASE_PASSWORD}" -e "SHOW DATABASES;" | grep -Ev "(${IGNORE_DATABASES})")

if [ -n "${DATABASE_NAME}" ]; then
  database_list=$(echo $database_list | grep -w "${DATABASE_NAME}")
fi

# Get the current date
current_date=$(date +"%Y/%m/%d")

# Loop through each database and dump it to a separate file
for db in $database_list; do
    echo "Starting dump of ${db} database(s) from ${DATABASE_HOST}..."
    mysqldump -h "${DATABASE_HOST}" -u "${DATABASE_USER}" -p"${DATABASE_PASSWORD}" --databases $db > $backup_dir/$db.sql
    # Set the S3 key
    dump_name=$(date +"%Y-%m-%d_%H-%M-%S")
    s3_key="${BUCKET_PREFIX}/$db/${current_date}/${db}_${dump_name}.sql"

    echo "Uploading $db.sql to S3"
    s3cmd put $backup_dir/$db.sql s3://${AWS_BUCKET}/$s3_key --storage-class=$STORAGE_CLASS
    echo "Upload complete for $db.sql to $s3_key"
done

echo "Done!"

exit 0
