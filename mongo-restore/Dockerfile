FROM python:3.13.0a4-alpine3.19

RUN apk update --no-cache && \
    apk add --no-cache mongodb-tools wget unzip

RUN pip install pymongo

ADD run.sh /run.sh
ADD audit.py /audit.py
RUN chmod +x /run.sh

CMD ["sh", "run.sh"]
