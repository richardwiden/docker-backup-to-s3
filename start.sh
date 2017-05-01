#!/bin/sh

set -e
test -z $DEBUG || set -x


: ${ACCESS_KEY:?"ACCESS_KEY env variable is required"}
: ${SECRET_KEY:?"SECRET_KEY env variable is required"}
: ${S3_PATH:?"S3_PATH env variable is required"}
: ${AES_PASSPHRASE:?"AES_PASSPHRASE env variable is required"}
export DATA_PATH=${DATA_PATH:-/data/}
export PARAMS="${PARAMS} --no-progress"
CRON_SCHEDULE=${CRON_SCHEDULE:-3 5 * * *}

echo "access_key=$ACCESS_KEY" >> /root/.s3cfg
echo "secret_key=$SECRET_KEY" >> /root/.s3cfg

case $1 in 

  backup-once)
    exec /backup.sh
    ;;

  schedule)
    echo "Scheduling backup cron: $CRON_SCHEDULE"
    CRONFILE='/etc/cron.d/backup'
    export LOGFILE='/var/log/backup.log'

    touch $LOGFILE

    # CRON_ENV="PARAMS='$PARAMS'\nDATA_PATH='$DATA_PATH'\nS3_PATH='$S3_PATH'\nPREFIX='$PREFIX'\nAES_PASSPHRASE='$AES_PASSPHRASE'"
    CRON_ENV="$(env)"
    echo -e "$CRON_ENV\n\n$CRON_SCHEDULE /backup.sh"  > $CRONFILE
    crontab $CRONFILE

    cron
    exec tail -f $LOGFILE
    ;;

  restore)
    : ${VERSION:?"VERSION env variable is required"}
    exec /restore.sh
    ;;

  *)
    echo "Error: must specify operation, one of backup-once, schedule or restore"
    exit 1
esac
