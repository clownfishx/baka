#!/bin/sh

set -e

export PGUSER="${DATABASE_USER}"
export PGPASSWORD="${DATABASE_PASSWORD}"
export PGHOST="${DATABASE_HOST}"
export PGPORT="${DATABASE_PORT}"

if [ -z "${FILE_URL}" ]; then
  echo "You need to set the FILE_URL environment variable."
  exit 1
fi

if [ -z "${DATABASE_NAME}" ]; then
  # Random uuid
  export DATABASE_NAME="$(python -c "import uuid; print(uuid.uuid4())")"
  echo "DATABASE_NAME is not set, using random uuid: ${DATABASE_NAME}"
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

# Download the file
echo "Downloading the file..."
wget -O /tmp/backup.dump "${FILE_URL}"

# Check database name is not exist
if psql -lqt | cut -d \| -f 1 | grep -qw "${DATABASE_NAME}"; then
  echo "Database ${DATABASE_NAME} already exists."
else
  echo "Database ${DATABASE_NAME} does not exist."
  echo "Creating ${DATABASE_NAME} database..."
  createdb "${DATABASE_NAME}"
fi

# Restore the database
echo "Starting restoring of ${DATABASE_NAME} database(s) from ${PGHOST}..."
pg_restore --no-owner -d "${DATABASE_NAME}" /tmp/backup.dump
echo "Restoring of ${DATABASE_NAME} database(s) from ${PGHOST} is done!"

if [ "${IS_AUDIT}" = "true" ]; then
  # Audit the database
  echo "Auditing the database..."
  echo "Database detail:"
  psql -d "${DATABASE_NAME}" -c "SELECT datname, pg_size_pretty(pg_database_size(datname)), datistemplate, datallowconn
           FROM pg_database
           WHERE datname = '${DATABASE_NAME}';"

  echo "Table detail with last updatedAt: "
  psql -d "${DATABASE_NAME}" -c "
  DO \$\$
  DECLARE
      r RECORD;
      result TIMESTAMP;
  BEGIN
      FOR r IN
          SELECT table_name
          FROM information_schema.tables
          WHERE table_schema = 'public'
      LOOP
          IF EXISTS (
              SELECT 1 FROM information_schema.columns
              WHERE table_name = r.table_name AND column_name = 'updatedAt'
          ) THEN
              EXECUTE format('SELECT \"updatedAt\" FROM %I ORDER BY \"updatedAt\" DESC LIMIT 1', r.table_name) INTO result;
              RAISE NOTICE '%: %', r.table_name, result;
          ELSE
              RAISE NOTICE '%: %', r.table_name, 'no-data';
          END IF;
      END LOOP;
  END \$\$;
  "

  echo "Database ${DATABASE_NAME} is audited!"
fi

if [ "${REMOVE_DATABASE}" = "true" ]; then
  # Remove the database
  echo "Removing the database..."
  dropdb "${DATABASE_NAME}"
  echo "Database ${DATABASE_NAME} is removed!"
fi

exit 0
