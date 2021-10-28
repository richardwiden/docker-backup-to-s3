#!/bin/bash
AWS_EC2_METADATA_DISABLED=true #https://github.com/aws/aws-cli/issues/5262#issuecomment-705832151
export AWS_EC2_METADATA_DISABLED

test -z $DEBUG || set -x

dateISO() {
  date -j -f "%s" $started -u  +"%Y-%m-%dT%H:%M:%SZ"
}

started=$(date +%s)
startedAt=$(date -u -d @$started  +"%Y-%m-%dT%H:%M:%SZ")

s3obj="$VERSION.tgz.aes"
tarfile="restore.tgz"


if [[ ! -z "${WIPE_TARGET}" && "${DATA_PATH}" != "/" ]]; then
  find $DATA_PATH/ -mindepth 1 -delete
fi

if [ -n "${S3_ENDPOINT}" ]; then
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
else
  AWS_ARGS=""
fi

output=$( aws $AWS_ARGS s3 cp $PARAMS "${S3_PATH}/${s3obj}" "$DATA_PATH" 2>&1 )
output=$(echo $output | sed -e 's/\r//g'| sed -e 's/\n//g')
code=$?
if [ $code ]; then
  cd $DATA_PATH

  openssl aes-256-cbc -iter 1000 -k "${AES_PASSPHRASE}" -in $s3obj -out $tarfile -d
  ssl_code=$?
  tar xzf $tarfile
  tar_code=$?

  if [[ $ssl_code && $tar_code ]]; then
    result="success"
  else
    result="error:unable to decrypt or untar"
  fi
else
  result="error:$code"
fi

rm -f $s3obj
rm -f $tarfile

printf "{\"restore\":{\"state\":\"restored\" } }\n"

if [[ ! -z "$POST_RESTORE_COMMAND" && "$result" == "success" ]]; then
  restore_cmd_out=$($POST_RESTORE_COMMAND)
  printf "{\"restore\":{\"state\":\"post-command-run\", \"output\":\"%s\", \"exitCode\":\"%s\"}}\n" "$restore_cmd_out" "$?" | jq

fi

finished=$(date +%s)
duration=$(( finished - started ))
printf "{\"restore\":{ \"state\":\"%s\", \"startedAt\":\"%s\",\"duration\":\"%i seconds\",\"from\":\"%s/%s\",\"output\":\"%s\"}}\n" "$result"  "$startedAt" "$duration" "$S3_PATH" "$s3obj" "$output" |jq


