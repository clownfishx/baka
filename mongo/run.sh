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

if [ -z "${MONGODB_USERNAME}" ]; then
  echo "You need to set the MONGODB_USERNAME environment variable."
  exit 1
fi

if [ -z "${MONGODB_PASSWORD}" ]; then
  echo "You need to set the MONGODB_PASSWORD environment variable."
  exit 1
fi

if [ -z "${MONGODB_HOST}" ]; then
  echo "You need to set the MONGODB_HOST environment variable."
  exit 1
fi

if [ -z "${MONGODB_PORT}" ]; then
  echo "You need to set the MONGODB_PORT environment variable."
  exit 1
fi

if [ -z "${STORAGE_CLASS}" ]; then
  export STORAGE_CLASS="ONEZONE_IA"
fi

# Set the directory where you want to store the dump files
backup_dir="/tmp"

#databases=$(mongo --host $MONGODB_HOST --port $MONGODB_PORT --username $MONGODB_USERNAME --password $MONGODB_PASSWORD --quiet --eval "db.adminCommand('listDatabases').databases.forEach(function(d){print(d.name)})")
output=$(python list_database.py)

# Print the output
echo "Output captured into shell variable:"

# Get the current date
current_date=$(date +"%Y/%m/%d")

# Loop through each database and dump it to a separate file
echo "$output" | while read -r line; do
    db=$line
    echo "Starting dump of ${db} database(s) from ${PGHOST}..."
    mongodump --authenticationDatabase=admin --uri="mongodb://${MONGODB_USERNAME}:${MONGODB_PASSWORD}@${MONGODB_HOST}:${MONGODB_PORT}/" --db $db --out $backup_dir/$db

    cd $backup_dir/$db
    zip -r "$backup_dir/$db.zip" *
    # Set the S3 key
    dump_name=$(date +"%Y-%m-%d_%H-%M-%S")
    s3_key="${BUCKET_PREFIX}/$db/${current_date}/${db}_${dump_name}.zip"

    echo "Uploading $db.dump to S3"
    s3cmd put $backup_dir/$db.zip s3://${AWS_BUCKET}/$s3_key --storage-class=$STORAGE_CLASS
    echo "Upload complete for $db.dump to $s3_key"
done

echo "Done!"

exit 0
