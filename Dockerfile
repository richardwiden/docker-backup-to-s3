FROM debian:jessie
MAINTAINER Strawpay <info@strawpay.com>

RUN apt-get update && \
    apt-get install -y python python-pip cron && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip install s3cmd

ADD s3cfg /root/.s3cfg

ADD start.sh /start.sh
RUN chmod +x /start.sh
ADD backup.sh /backup.sh
RUN chmod +x /backup.sh
ADD restore.sh /restore.sh
RUN chmod +x /restore.sh

ENTRYPOINT ["/start.sh"]
CMD [""]
