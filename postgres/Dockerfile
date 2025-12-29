FROM python:3.13.0a4-alpine3.19

RUN apk update --no-cache && \
    apk add --no-cache postgresql18-client

RUN pip install awscli

ENV PGDUMP_OPTIONS -Fc --no-acl --no-owner

ADD run.sh /run.sh
RUN chmod +x /run.sh

CMD ["sh", "run.sh"]
