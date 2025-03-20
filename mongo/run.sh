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

# Loop through each database and dump it to a separate file
echo "$output" | while read -r line; do
    db=$line
    echo "Starting dump of ${db} database(s) from ${PGHOST}..."
    mongodump --authenticationDatabase=admin --uri="mongodb://${DATABASE_USER}:${DATABASE_PASSWORD}@${DATABASE_HOST}:${DATABASE_PORT}/" --db $db --out $backup_dir/$db

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
