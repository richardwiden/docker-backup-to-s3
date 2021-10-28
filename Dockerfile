FROM alpine
LABEL org.opencontainers.image.authors="richardwiden@gmail.com"
MAINTAINER "richardwiden@gmail.com"
LABEL version="1.0"

RUN apk update && \
    apk add -f py-pip apk-cron curl openssl bash jq && \
    pip install -U pip && \
    pip install awscli && \
    rm -rf /var/cache/apk/*

ADD s3cfg /root/.s3cfg
ADD start.sh /start.sh
ADD backup.sh /backup.sh
ADD restore.sh /restore.sh
RUN chmod +x /restore.sh /backup.sh /start.sh
ENTRYPOINT ["/start.sh"]
