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

if [ -z "${MYSQL_USER}" ]; then
  echo "You need to set the MYSQL_USER environment variable."
  exit 1
fi

if [ -z "${MYSQL_PASSWORD}" ]; then
  echo "You need to set the MYSQL_PASSWORD environment variable."
  exit 1
fi

if [ -z "${MYSQL_HOST}" ]; then
  echo "You need to set the MYSQL_HOST environment variable."
  exit 1
fi

# Set the directory where you want to store the dump files
backup_dir="/tmp"

# Get a list of MySQL databases, excluding system databases
database_list=$(mariadb -h "${MYSQL_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

# Get the current date
current_date=$(date +"%Y/%m/%d")

# Loop through each database and dump it to a separate file
for db in $database_list; do
    echo "Starting dump of ${db} database(s) from ${MYSQL_HOST}..."
    mysqldump -h "${MYSQL_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --databases $db > $backup_dir/$db.sql
    # Set the S3 key
    dump_name=$(date +"%Y-%m-%d_%H-%M-%S")
    s3_key="${BUCKET_PREFIX}/$db/${current_date}/${db}_${dump_name}.sql"

    echo "Uploading $db.sql to S3"
    s3cmd put $backup_dir/$db.sql s3://${AWS_BUCKET}/$s3_key
    echo "Upload complete for $db.sql to $s3_key"
done

echo "Done!"

exit 0
