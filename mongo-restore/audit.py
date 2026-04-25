import os

from pymongo import MongoClient

MONGO_URI = os.environ['MONGO_URI']
TARGET_DB = os.environ['TARGET_DB']

UPDATED_AT_FIELDS = ('updatedAt', 'updated_at', 'updatedat')

client = MongoClient(MONGO_URI)
db = client[TARGET_DB]

stats = db.command('dbStats')
print('Database detail:')
print(f"  name: {TARGET_DB}")
print(f"  storageSize: {stats.get('storageSize')}")
print(f"  dataSize: {stats.get('dataSize')}")
print(f"  collections: {stats.get('collections')}")
print(f"  objects: {stats.get('objects')}")

print('Collection detail with last updatedAt:')
for coll_name in db.list_collection_names():
    coll = db[coll_name]
    count = coll.estimated_document_count()
    last = 'no-data'
    for field in UPDATED_AT_FIELDS:
        try:
            doc = coll.find_one({field: {'$exists': True}}, sort=[(field, -1)])
        except Exception:
            doc = None
        if doc and field in doc:
            last = doc[field]
            break
    print(f"  {coll_name}: count={count}, last_updated={last}")
