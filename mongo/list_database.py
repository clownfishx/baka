from pymongo import MongoClient

import os
DATABASE_USER=os.getenv('DATABASE_USER')
DATABASE_PASSWORD=os.getenv('DATABASE_PASSWORD')
DATABASE_HOST=os.getenv('DATABASE_HOST')
DATABASE_PORT=os.getenv('DATABASE_PORT')
IGNORE_DATABASES=os.getenv('IGNORE_DATABASES')
DATABASE_NAME=os.getenv('DATABASE_NAME')

excludes = ['admin', 'config', 'local']
if IGNORE_DATABASES:
    excludes += IGNORE_DATABASES.split(',')

# Connect to MongoDB
client = MongoClient(f'mongodb://{DATABASE_USER}:{DATABASE_PASSWORD}@{DATABASE_HOST}:{DATABASE_PORT}/')

# List all the databases
database_names = client.list_database_names()

# Print the list of database names
for db_name in database_names:
    if DATABASE_NAME:
        if db_name == DATABASE_NAME:
            print(db_name)
    else:
        if db_name not in excludes:
            print(db_name)
