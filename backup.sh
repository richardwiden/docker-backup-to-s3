#!/bin/bash
#AWS_EC2_METADATA_DISABLED=true #https://github.com/aws/aws-cli/issues/5262#issuecomment-705832151
#export AWS_EC2_METADATA_DISABLED
test -z $DEBUG || set -x

dateISO() {
  date -j -f "%s" $started -u  +"%Y%m%dT%H%M%SZ"
}

runbackup() {
  started=$(date +%s)
  startedAt=$(date -u -d @$started  +"%Y%m%dT%H%M%SZ")
  if [ -n "${S3_ENDPOINT}" ]; then
    AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
  else
    AWS_ARGS=""
  fi
  #printf "{\"backup\":{\"state\":\"start\", \"startedAt\":\"%s\", \"message\":\"%s\"}}" "$startedAt" "Starting backup from: $DATA_PATH to $S3_PATH/$s3name" | jq

  if [ "$PREFIX" ]; then
      version="$PREFIX-$startedAt"
  else
      version="$startedAt"
  fi
  if [ -n "$EXCLUDE_FILES" ]; then
    EXCLUDE_TAR="--exclude='$EXCLUDE_FILES'"
  else
    EXCLUDE_TAR=""
  fi
  export version

  name=$version.tgz
  s3name=$name.aes

  tar czf /tmp/$name $EXCLUDE_TAR -C $DATA_PATH .
  openssl enc -aes-256-cbc -iter 1000 -k "${AES_PASSPHRASE}" -in /tmp/$name -out /tmp/$s3name

  output="$( aws $AWS_ARGS s3 cp $PARAMS "/tmp/$s3name" "$S3_PATH/$s3name" 2>&1 )"
  output=$(echo $output | sed -e 's/\r//g'| sed -e 's/\n//g')

  code=$?
  if [ $code ]; then
      result="success"
  else
      result="error:$code"
  fi

  rm -f /tmp/$name
  rm -f /tmp/$s3name

  finished=$(date +%s)
  duration=$(( finished - started ))

  version=$(echo $version | sed -e 's/\r//g'| sed -e 's/\n//g')
  #printf "{\"backup\": { \"state\":\"%s\", \"startedAt\":\"%s\", \"duration\":\"%i seconds\",\"version\":\"%s\", \"name\":\"%s/%s\", \"output\":\"%s\"}}"  "$result" "$startedAt" "$duration" "$version" "$S3_PATH" "$s3name" "$output"|jq
  printf "%s" "$version"
}



(
  flock -n 200 || exit 1

  exec &> >( tee -a ${LOGFILE:-/var/log/backup.log} )
  # exec 2>&1
  runbackup
) 200> /var/lock/backup

