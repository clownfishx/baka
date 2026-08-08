"""
mongodump-compatible dumper that survives CursorNotFound by streaming
each collection with no_cursor_timeout=True and resuming from the last
successfully-written _id when the cursor is killed.

Output layout matches `mongodump --out <dir> --db <db>`:
    <DUMP_OUT>/<DUMP_DB>/<collection>.bson
    <DUMP_OUT>/<DUMP_DB>/<collection>.metadata.json

So mongorestore can consume the result without modification.
"""
import os
import sys
import time
from pathlib import Path

from bson import BSON
from bson.json_util import dumps as bson_dumps
from pymongo import ASCENDING, MongoClient
from pymongo.errors import AutoReconnect, CursorNotFound, NetworkTimeout

DATABASE_USER = os.environ['DATABASE_USER']
DATABASE_PASSWORD = os.environ['DATABASE_PASSWORD']
DATABASE_HOST = os.environ['DATABASE_HOST']
DATABASE_PORT = os.environ['DATABASE_PORT']
READ_PREFERENCE = os.getenv('READ_PREFERENCE', '')
DB_NAME = os.environ['DUMP_DB']
OUT_DIR = os.environ['DUMP_OUT']
BATCH_SIZE = int(os.getenv('DUMP_BATCH_SIZE', '1000'))
MAX_RETRIES = int(os.getenv('DUMP_MAX_RETRIES', '10'))

uri = (
    f"mongodb://{DATABASE_USER}:{DATABASE_PASSWORD}"
    f"@{DATABASE_HOST}:{DATABASE_PORT}/?authSource=admin"
)
if READ_PREFERENCE:
    uri += f"&readPreference={READ_PREFERENCE}"

client = MongoClient(uri)
db = client[DB_NAME]

out_db_dir = Path(OUT_DIR) / DB_NAME
out_db_dir.mkdir(parents=True, exist_ok=True)


def collection_options(name):
    info = db.command('listCollections', filter={'name': name})
    batch = info.get('cursor', {}).get('firstBatch', [])
    return batch[0].get('options', {}) if batch else {}


def write_metadata(coll_name, path):
    indexes = [{k: v for k, v in idx.items() if k != 'ns'}
               for idx in db[coll_name].list_indexes()]
    metadata = {
        'options': collection_options(coll_name),
        'indexes': indexes,
        'type': 'collection',
    }
    path.write_text(bson_dumps(metadata))


def dump_collection(coll_name):
    coll = db[coll_name]
    bson_path = out_db_dir / f"{coll_name}.bson"
    meta_path = out_db_dir / f"{coll_name}.metadata.json"

    write_metadata(coll_name, meta_path)

    last_id = None
    total = 0
    retries = 0
    with bson_path.open('wb') as f:
        while True:
            query = {} if last_id is None else {'_id': {'$gt': last_id}}
            cursor = coll.find(
                query,
                no_cursor_timeout=True,
                batch_size=BATCH_SIZE,
            ).sort('_id', ASCENDING)
            try:
                try:
                    for doc in cursor:
                        f.write(BSON.encode(doc))
                        last_id = doc['_id']
                        total += 1
                finally:
                    try:
                        cursor.close()
                    except Exception:
                        pass
                break
            except (CursorNotFound, AutoReconnect, NetworkTimeout) as e:
                retries += 1
                if retries > MAX_RETRIES:
                    print(
                        f"  {DB_NAME}.{coll_name}: giving up after "
                        f"{retries} retries ({total} docs written)",
                        file=sys.stderr,
                    )
                    raise
                backoff = min(2 ** retries, 30)
                print(
                    f"  {DB_NAME}.{coll_name}: {type(e).__name__} after "
                    f"{total} docs, resuming from _id > {last_id} "
                    f"(retry {retries}/{MAX_RETRIES}, sleep {backoff}s)",
                    file=sys.stderr,
                )
                time.sleep(backoff)

    print(f"  {DB_NAME}.{coll_name}: {total} docs")


for name in db.list_collection_names():
    if name.startswith('system.'):
        continue
    print(f"Dumping {DB_NAME}.{name}...")
    dump_collection(name)

print(f"Dump of {DB_NAME} complete -> {out_db_dir}")
