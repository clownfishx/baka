from pymongo import MongoClient

import os
MONGODB_USERNAME=os.getenv('MONGODB_USERNAME')
MONGODB_PASSWORD=os.getenv('MONGODB_PASSWORD')
MONGODB_HOST=os.getenv('MONGODB_HOST')
MONGODB_PORT=os.getenv('MONGODB_PORT')
IGNORE_DATABASES=os.getenv('IGNORE_DATABASES')
DATABASE_NAME=os.getenv('DATABASE_NAME')

excludes = ['admin', 'config', 'local']
if IGNORE_DATABASES:
    excludes += IGNORE_DATABASES.split(',')

# Connect to MongoDB
client = MongoClient(f'mongodb://{MONGODB_USERNAME}:{MONGODB_PASSWORD}@{MONGODB_HOST}:{MONGODB_PORT}/')

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
