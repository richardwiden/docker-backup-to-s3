#!/bin/bash
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

  export version

  name=$version.tgz
  s3name=$name.aes
  #echo "tar $EXCLUDE_TAR -czv -f /tmp/$name -C $DATA_PATH  ."
  if [ -n "$EXCLUDE_FILES" ]; then
    tar -czf /tmp/$name -C $DATA_PATH --exclude=$EXCLUDE_FILES .
  else
    tar -czf /tmp/$name -C $DATA_PATH  .
  fi

  openssl enc -aes-256-cbc -iter 1000 -k "${AES_PASSPHRASE}" -in /tmp/$name -out /tmp/$s3name

  output="$( aws $AWS_ARGS s3 cp /tmp/$s3name $S3_PATH/$s3name --no-progress 2>&1 )"
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
  deleted=""
  sleep 1
  #Delete old
  if [ -n "$DELETE_OLDER_THAN" ]; then
    list_command=$(aws $AWS_ARGS s3 ls "$S3_PATH/")
    while read -r line;
    do
      createDate=$(echo "$line"|awk {'print $1" "$2'}| sed -e 's/\r//g'| sed -e 's/\n//g')
      createDate=$(date -d "$createDate" +%s| sed -e 's/\r//g'| sed -e 's/\n//g')
      olderThan=$(date --date "$DELETE_OLDER_THAN" +%s| sed -e 's/\r//g'| sed -e 's/\n//g')
      if [[ $createDate -lt $olderThan ]]; then
        fileName=$(echo "$line" |awk {'print $4'}| sed -e 's/\r//g'| sed -e 's/\n//g')
        if [[ $fileName != "" ]]; then
          delete_output=$(aws $AWS_ARGS s3 rm "$S3_PATH/$fileName")
          case "$delete_output" in
            *"aws: error"*)
              result="error:failed: aws $AWS_ARGS s3 rm $S3_PATH/$fileName"
              break;
              ;;
          esac
          if [ "$deleted" = "" ]; then
            deleted=$delete_output
          else
            deleted="$deleted,$delete_output"
          fi
        fi
      fi
    done < <(echo "$list_command" )
  fi

  printf "{\"backup\": { \"state\":\"%s\", \"startedAt\":\"%s\", \"duration\":\"%i seconds\",\"version\":\"%s\", \"name\":\"%s/%s\", \"output\":\"%s\"}, \"deleted\":\"%s\"}"  "$result" "$startedAt" "$duration" "$version" "$S3_PATH" "$s3name" "$output" "$deleted" | jq
}

(
  flock -n 200 || exit 1

  exec &> >( tee -a ${LOGFILE:-/var/log/backup.log} )
  # exec 2>&1
  runbackup
) 200> /var/lock/backup

