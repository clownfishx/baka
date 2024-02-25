from pymongo import MongoClient

import os
MONGODB_USERNAME=os.getenv('MONGODB_USERNAME')
MONGODB_PASSWORD=os.getenv('MONGODB_PASSWORD')
MONGODB_HOST=os.getenv('MONGODB_HOST')
MONGODB_PORT=os.getenv('MONGODB_PORT')
# Connect to MongoDB
client = MongoClient(f'mongodb://{MONGODB_USERNAME}:{MONGODB_PASSWORD}@{MONGODB_HOST}:{MONGODB_PORT}/')

# List all the databases
database_names = client.list_database_names()
excludes = ['config', 'local']
# Print the list of database names
for db_name in database_names:
    if db_name not in excludes:
        print(db_name)
