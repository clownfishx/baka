FROM python:3.13.0a4-alpine3.19

RUN apk update --no-cache && \
    apk add mongodb-tools zip

RUN pip install s3cmd pymongo

ADD run.sh /run.sh
ADD list_database.py /list_database.py
RUN chmod +x /run.sh

CMD ["sh", "run.sh"]
