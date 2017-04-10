#!/bin/bash

set -e

dateISO() {
    date -j -f "%s" $started -u  +"%Y-%m-%dT%H:%M:%SZ"
}

started=$(date +%s)
startedAt=$(date -u -d @$started  +"%Y-%m-%dT%H:%M:%SZ")

s3obj=$VERSION.tgz.aes
tarfile=restore.tgz

#echo "Starting restore $S3_PATH/$s3obj to:$DATA_PATH" 

output=$(/usr/local/bin/s3cmd sync $PARAMS "${S3_PATH}${s3obj}" $DATA_PATH 2>&1 | tr '\n' ';' )
code=$?
if [ $code ]; then
    result=ok
    cd $DATA_PATH
    openssl aes-256-cbc -k "${AES_PASSPHRASE}" -in $s3obj -out $tarfile -d
    tar xzf $tarfile
else
    result="error:$code"
fi

rm -f $s3obj
rm -f $tarfile

finished=$(date +%s)
duration=$(( finished - started ))
printf "{\"restore\":{ \"startedAt\":\"%s\",\"duration\":\"PT%is\",\"from\":\"%s/%s\",\"result\":\"%s\",\"output\":\"%s\"}}\n" "$startedAt" "$duration" "$S3_PATH" "$s3obj" "$result" "$output"
