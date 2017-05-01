#!/bin/sh

set -e
test -z $DEBUG || set -x

dateISO() {
  date -j -f "%s" $started -u  +"%Y-%m-%dT%H:%M:%SZ"
}

started=$(date +%s)
startedAt=$(date -u -d @$started  +"%Y-%m-%dT%H:%M:%SZ")

s3obj="$VERSION.tgz.aes"
tarfile="restore.tgz"


if [ ! -z "${WIPE_TARGET}" ]; then
  find $DATA_PATH/ -mindepth 1 -delete
fi


output=$(s3cmd $PARAMS get "${S3_PATH}/${s3obj}" $DATA_PATH 2>&1 | tr '\n' ';' )
code=$?
if [ $code ]; then
  result="ok"
  cd $DATA_PATH

  openssl aes-256-cbc -k "${AES_PASSPHRASE}" -in $s3obj -out $tarfile -d
  tar xzf $tarfile
else
  result="error:$code"
fi

rm -f $s3obj
rm -f $tarfile

printf "{\"restore\":{\"state\":\"restored\" } }\n"

if [[ ! -z "$POST_RESTORE_COMMAND" && $result == "ok" ]]; then
  restore_cmd_out=$($POST_RESTORE_COMMAND)
  printf "{\"restore\":{\"state\":\"post-command-run\", \"output\":\"%s\", \"exitCode\":\"%s\"}}\n" "$restore_cmd_out" "$?"

fi

finished=$(date +%s)
duration=$(( finished - started ))
printf "{\"restore\":{ \"state\":\"success\", \"startedAt\":\"%s\",\"duration\":\"PT%is\",\"from\":\"%s/%s\",\"result\":\"%s\",\"output\":\"%s\"}}\n" "$startedAt" "$duration" "$S3_PATH" "$s3obj" "$result" "$output"


