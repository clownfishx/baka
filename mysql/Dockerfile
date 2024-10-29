FROM python:3.13.0a4-alpine3.19

RUN apk update --no-cache && \
    apk add --no-cache mariadb-client mariadb-connector-c-dev

RUN pip install s3cmd

ENV PGDUMP_OPTIONS -Fc --no-acl --no-owner

ADD run.sh /run.sh
RUN chmod +x /run.sh

CMD ["sh", "run.sh"]
